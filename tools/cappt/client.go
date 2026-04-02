package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	headerTimeout  = 10 * time.Second  // time to receive response headers
	requestTimeout = 30 * time.Second  // total timeout for regular API calls
	sseTimeout     = 600 * time.Second // total timeout for SSE streams (PPT generation)
	sseHeaderTimeout = 30 * time.Second // SSE header timeout (server may buffer before streaming)
)

type Client struct {
	baseURL string
	token   string
	http    *http.Client // regular API calls (status, logout)
	httpSSE *http.Client // SSE stream (generate)
}

func NewClient(token string) *Client {
	return &Client{
		baseURL: resolveBaseURL(),
		token:   token,
		http: &http.Client{
			Timeout: requestTimeout,
			Transport: &http.Transport{
				ResponseHeaderTimeout: headerTimeout,
			},
		},
		httpSSE: &http.Client{
			Timeout: sseTimeout,
			Transport: &http.Transport{
				ResponseHeaderTimeout: sseHeaderTimeout,
			},
		},
	}
}

func (c *Client) newRequest(method, path string, body io.Reader) (*http.Request, error) {
	url := strings.TrimRight(c.baseURL, "/") + path
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	return req, nil
}

func (c *Client) GetStatus() (*TokenStatus, error) {
	req, err := c.newRequest(http.MethodGet, "/openapi/status", nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("cannot reach Cappt API: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	var result struct {
		Code int          `json:"code"`
		Msg  string       `json:"msg"`
		Data *TokenStatus `json:"data"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("non-JSON response (HTTP %d): %s", resp.StatusCode, truncate(string(body), 300))
	}
	if result.Code == 401 {
		clearCachedToken()
		return nil, fmt.Errorf("token invalid or expired (local cache cleared)")
	}
	if result.Code != 200 {
		return nil, fmt.Errorf("status check failed (code %d): %s", result.Code, result.Msg)
	}
	if result.Data == nil {
		return nil, fmt.Errorf("API returned no data")
	}
	return result.Data, nil
}

func (c *Client) Logout() error {
	req, err := c.newRequest(http.MethodPost, "/openapi/logout", nil)
	if err != nil {
		return err
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("cannot reach Cappt API: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	var result struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return fmt.Errorf("non-JSON response (HTTP %d): %s", resp.StatusCode, truncate(string(body), 300))
	}
	if result.Code == 401 {
		clearCachedToken()
		return nil
	}
	if result.Code != 200 {
		return fmt.Errorf("logout failed (code %d): %s", result.Code, result.Msg)
	}
	clearCachedToken()
	return nil
}

func (c *Client) GeneratePresentation(outline string, includeGallery, includePreview bool) (map[string]any, error) {
	payload, _ := json.Marshal(map[string]any{
		"outline":        outline,
		"includeGallery": includeGallery,
		"includePreview": includePreview,
	})

	req, err := c.newRequest(http.MethodPost, "/openapi/ai/chat/ppt", bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "text/event-stream")

	resp, err := c.httpSSE.Do(req)
	if err != nil {
		return nil, fmt.Errorf("cannot reach Cappt API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		clearCachedToken()
		return nil, &apiError{code: 401, msg: "ERROR: token invalid or expired. Local cache cleared. Run: cappt login"}
	}
	if resp.StatusCode != http.StatusOK {
		preview := make([]byte, 300)
		n, _ := resp.Body.Read(preview)
		return nil, fmt.Errorf("Cappt API HTTP %d: %s", resp.StatusCode, string(preview[:n]))
	}

	return parseSSEStream(resp.Body)
}
