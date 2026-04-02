package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

const (
	defaultBaseURL = "https://api.cappt.cc"
	version        = "0.0.1"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(2)
	}

	cmd := os.Args[1]
	switch cmd {
	case "version", "--version", "-v":
		fmt.Println(version)
	case "login":
		runLogin(os.Args[2:])
	case "whoami":
		runWhoami(os.Args[2:])
	case "logout":
		runLogout(os.Args[2:])
	case "generate":
		runGenerate(os.Args[2:])
	case "help", "--help", "-h":
		printUsage()
	default:
		fmt.Fprintf(os.Stderr, "ERROR: unknown command %q\n\n", cmd)
		printUsage()
		os.Exit(2)
	}
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `cappt - Cappt API CLI

Usage:
  cappt <command> [options]

Commands:
  login       Get login URL or save token after browser login
  whoami      Check current login status and token info
  logout      Revoke current token and clear local cache
  generate    Generate a PPT presentation from a Markdown outline
  version     Print CLI version
  help        Show this help message

Run "cappt <command> --help" for command-specific options.
`)
}

func runLogin(args []string) {
	fs := flag.NewFlagSet("login", flag.ExitOnError)
	token := fs.String("token", "", "Save this token after copying it from the browser")
	utmSource := fs.String("utm-source", "", "Platform identifier for analytics (e.g. claude-code, cursor). Overrides CAPPT_UTM_SOURCE env var")
	fs.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: cappt login [--token TOKEN] [--utm-source NAME]

Login flow:
  Step 1: cappt login              Print the login URL to stdout
  Step 2: Open the URL in browser, login, copy the token shown
  Step 3: cappt login --token <token>  Save the token locally

Set CAPPT_BASE_URL env var to use a custom API endpoint.

Options:
`)
		fs.PrintDefaults()
	}
	fs.Parse(args)

	baseURL := resolveBaseURL()

	if *token != "" {
		if err := loginSaveToken(*token, baseURL); err != nil {
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(1)
		}
		return
	}

	if err := loginGetURL(baseURL, resolveUTMSource(*utmSource)); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
}

func runWhoami(args []string) {
	flag.NewFlagSet("whoami", flag.ExitOnError).Parse(args)

	token := loadCachedToken()
	if token == "" {
		if ev := strings.TrimSpace(os.Getenv("CAPPT_TOKEN")); ev != "" {
			token = ev
		}
	}
	if token == "" {
		fmt.Fprintln(os.Stderr, "ERROR: not logged in. Run: cappt login")
		os.Exit(1)
	}

	status, err := NewClient(token).GetStatus()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Account:     %s\n", status.UserName)
	fmt.Fprintf(os.Stderr, "Token:       %s\n", status.Token.Name)
	fmt.Fprintf(os.Stderr, "Expires:     %s\n", status.Token.ExpireTime)
	fmt.Fprintf(os.Stderr, "Last used:   %s\n", status.Token.LastUseTime)
	fmt.Fprintf(os.Stderr, "Created:     %s\n", status.Token.CreateTime)
	os.Exit(0)
}

func runLogout(args []string) {
	flag.NewFlagSet("logout", flag.ExitOnError).Parse(args)

	token, err := resolveToken("")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Not logged in.")
		os.Exit(0)
	}

	if err := NewClient(token).Logout(); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stderr, "Logged out. Local token cache cleared.")
}

func runGenerate(args []string) {
	fs := flag.NewFlagSet("generate", flag.ExitOnError)
	var (
		outline        string
		outlineFile    string
		includeGallery bool
		includePreview bool
		token          string
	)
	fs.StringVar(&outline, "outline", "", "Markdown outline as a string")
	fs.StringVar(&outlineFile, "outline-file", "", "Path to a file containing the Markdown outline")
	fs.BoolVar(&includeGallery, "include-gallery", false, "Include all slide image URLs in the response")
	fs.BoolVar(&includePreview, "include-preview", false, "Include a preview image URL in the response")
	fs.StringVar(&token, "token", "", "Cappt API token (overrides CAPPT_TOKEN env and cached token)")
	fs.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: cappt generate --outline-file FILE [options]\n\nGenerate a PPT presentation from a Markdown outline.\n\nOptions:\n")
		fs.PrintDefaults()
	}
	fs.Parse(args)

	if outline == "" && outlineFile == "" {
		fmt.Fprintln(os.Stderr, "ERROR: one of --outline or --outline-file is required")
		os.Exit(2)
	}
	if outline != "" && outlineFile != "" {
		fmt.Fprintln(os.Stderr, "ERROR: --outline and --outline-file are mutually exclusive")
		os.Exit(2)
	}

	outlineText := loadOutline(outline, outlineFile)

	resolvedToken, err := resolveToken(token)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	data, err := NewClient(resolvedToken).GeneratePresentation(outlineText, includeGallery, includePreview)
	if err != nil {
		fatalAPIError(err)
	}

	out, _ := json.MarshalIndent(data, "", "  ")
	fmt.Println(string(out))
}

func loadOutline(inline, filePath string) string {
	if inline != "" {
		t := strings.TrimSpace(inline)
		if t == "" {
			fmt.Fprintln(os.Stderr, "ERROR: --outline text is empty")
			os.Exit(2)
		}
		return t
	}

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: outline file not found: %s\n", filePath)
		os.Exit(2)
	}
	content, err := os.ReadFile(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to read outline file: %v\n", err)
		os.Exit(2)
	}
	t := strings.TrimSpace(string(content))
	if t == "" {
		fmt.Fprintf(os.Stderr, "ERROR: outline file is empty: %s\n", filePath)
		os.Exit(2)
	}
	return t
}
