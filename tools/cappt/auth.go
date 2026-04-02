package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

type TokenStatus struct {
	UserID   string `json:"userId"`
	UserName string `json:"userName"`
	Token    struct {
		Name        string `json:"name"`
		ExpireTime  string `json:"expireTime"`
		LastUseTime string `json:"lastUseTime"`
		CreateTime  string `json:"createTime"`
	} `json:"token"`
}

func resolveBaseURL() string {
	if u := strings.TrimSpace(os.Getenv("CAPPT_BASE_URL")); u != "" {
		return u
	}
	return defaultBaseURL
}

func configDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "cappt")
}

func authFilePath() string {
	if d := configDir(); d != "" {
		return filepath.Join(d, "auth.json")
	}
	return ""
}

func loadCachedToken() string {
	path := authFilePath()
	if path == "" {
		return ""
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	var obj map[string]string
	if err := json.Unmarshal(data, &obj); err != nil {
		return ""
	}
	return strings.TrimSpace(obj["token"])
}

func saveToken(token string) error {
	path := authFilePath()
	if path == "" {
		return fmt.Errorf("cannot determine home directory")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, _ := json.MarshalIndent(map[string]string{"token": token}, "", "  ")
	return os.WriteFile(path, data, 0o600)
}

func clearCachedToken() {
	if path := authFilePath(); path != "" {
		os.Remove(path)
	}
}

func resolveToken(flagToken string) (string, error) {
	if flagToken != "" {
		return flagToken, nil
	}
	if t := strings.TrimSpace(os.Getenv("CAPPT_TOKEN")); t != "" {
		return t, nil
	}
	if t := loadCachedToken(); t != "" {
		return t, nil
	}
	return "", fmt.Errorf("not logged in. Run:\n  cappt login\n  cappt login --token <token>")
}

func resolveUTMSource(flag string) string {
	if flag != "" {
		return flag
	}
	if v := strings.TrimSpace(os.Getenv("CAPPT_UTM_SOURCE")); v != "" {
		return v
	}
	return "cappt"
}

func loginGetURL(baseURL, utmSource string) error {
	authURL := strings.TrimRight(baseURL, "/") + "/openapi/auth?utm_source=" + utmSource

	resp, err := http.Get(authURL)
	if err != nil {
		return fmt.Errorf("cannot reach Cappt auth endpoint (%s): %w", authURL, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	var result struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
		Data struct {
			URL string `json:"url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return fmt.Errorf("non-JSON response from auth endpoint (HTTP %d): %s", resp.StatusCode, truncate(string(body), 300))
	}
	if result.Code != 200 {
		return fmt.Errorf("failed to get login URL (code %d): %s", result.Code, result.Msg)
	}
	if result.Data.URL == "" {
		return fmt.Errorf("auth response missing url field")
	}

	fmt.Println(result.Data.URL)
	return nil
}

func loginSaveToken(token, baseURL string) error {
	if err := saveToken(token); err != nil {
		return fmt.Errorf("failed to save token: %w", err)
	}
	c := NewClient(token)
	c.baseURL = baseURL
	if status, err := c.GetStatus(); err == nil {
		fmt.Fprintf(os.Stderr, "Logged in as %s (token: %s, expires: %s)\n", status.UserName, status.Token.Name, status.Token.ExpireTime)
	}
	fmt.Fprintln(os.Stderr, "Token saved to ~/.config/cappt/auth.json")
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
