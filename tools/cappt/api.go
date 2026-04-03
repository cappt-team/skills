package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

func parseSSEStream(body io.Reader) (map[string]any, error) {
	var total int
	scanner := bufio.NewScanner(body)
	for scanner.Scan() {
		line := scanner.Text()

		if strings.HasPrefix(line, ":") || !strings.HasPrefix(line, "data: ") {
			continue
		}

		dataStr := line[6:]
		if dataStr == "[DONE]" {
			break
		}

		var event struct {
			Code int            `json:"code"`
			Msg  string         `json:"msg"`
			Data map[string]any `json:"data"`
		}
		if err := json.Unmarshal([]byte(dataStr), &event); err != nil {
			continue
		}

		if event.Code != 200 {
			return nil, apiErrorFromCode(event.Code, event.Msg)
		}

		status, _ := event.Data["status"].(string)
		switch status {
		case "fill_outline":
			fmt.Fprintln(os.Stderr, "Refining outline...")
		case "begin":
			if t, ok := event.Data["total"].(float64); ok {
				total = int(t)
			}
			fmt.Fprintf(os.Stderr, "Generating %d slides\n", total)
		case "slide_start":
			if idx, ok := event.Data["index"].(float64); ok {
				fmt.Fprintf(os.Stderr, "[%d/%d] Generating slide %d...\n", int(idx), total, int(idx))
			}
		case "slide_finish":
			idx, _ := event.Data["index"].(float64)
			finish, _ := event.Data["finish"].(float64)
			timeCost, _ := event.Data["timeCost"].(float64)
			fmt.Fprintf(os.Stderr, "[%d/%d] Slide %d done (%.1fs)\n", int(finish), total, int(idx), timeCost)
		case "finish":
			timeCost, _ := event.Data["timeCost"].(float64)
			fmt.Fprintf(os.Stderr, "All slides done (%.1fs)\n", timeCost)
			return event.Data, nil
		case "fail":
			errMsg, _ := event.Data["error"].(string)
			if errMsg == "" {
				errMsg = "unknown reason"
			}
			return nil, fmt.Errorf("generation failed: %s", errMsg)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("stream interrupted: %w", err)
	}
	return nil, fmt.Errorf("stream ended without a result")
}

type apiError struct {
	code int
	msg  string
}

func (e *apiError) Error() string { return e.msg }

func apiErrorFromCode(code int, msg string) error {
	switch code {
	case 5410:
		return &apiError{code: code, msg: fmt.Sprintf("ERROR: out of AI credits. %s", msg)}
	case 500:
		return &apiError{code: code, msg: fmt.Sprintf("ERROR: internal server error. %s", msg)}
	case 401:
		clearCachedToken()
		return &apiError{code: 401, msg: "ERROR: token invalid or expired. Local cache cleared. Run: cappt login"}
	default:
		return &apiError{code: code, msg: fmt.Sprintf("ERROR: Cappt API error (code %d): %s", code, msg)}
	}
}

func fatalAPIError(err error) {
	fmt.Fprintln(os.Stderr, err.Error())
	os.Exit(1)
}
