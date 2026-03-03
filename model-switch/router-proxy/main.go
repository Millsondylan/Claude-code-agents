package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// --- Types ---

type messageReq struct {
	Model     string         `json:"model"`
	MaxTokens int            `json:"max_tokens"`
	Stream    bool           `json:"stream,omitempty"`
	Messages  []anthropicMsg `json:"messages"`
}

type anthropicMsg struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

type provider int

const (
	providerClaude provider = iota
	providerKimi
	providerGLM
)

var providerNames = [...]string{"claude", "kimi", "glm"}

func main() {
	addr := envOr("MODEL_ROUTER_ADDR", ":3001")
	anthropicBase := strings.TrimRight(envOr("ANTHROPIC_UPSTREAM_BASE", "https://api.anthropic.com"), "/")
	litellmBase := strings.TrimRight(envOr("LITELLM_BASE_URL", "http://127.0.0.1:4000"), "/")
	litellmKey := envOr("LITELLM_API_KEY", "sk-litellm-local-proxy-key")

	// Kimi config - model name must match LiteLLM's model_name in config.yaml
	kimiModel := envOr("KIMI_MODEL", "kimi-k2.5")
	kimiMaxTokens := envOrInt("KIMI_MAX_TOKENS", 16384)

	// GLM config - model name must match LiteLLM's model_name in config.yaml
	glmModel := envOr("GLM_MODEL", "glm-5")
	glmMaxTokens := envOrInt("GLM_MAX_TOKENS", 16384)

	// Per-provider temperature and top_p settings
	// -1 means "don't inject" (let the provider use its own default)
	claudeTemp := envOrFloat("CLAUDE_TEMPERATURE", -1)
	kimiTemp := envOrFloat("KIMI_TEMPERATURE", 0.7)
	kimiTopP := envOrFloat("KIMI_TOP_P", 0.95)
	glmTemp := envOrFloat("GLM_TEMPERATURE", 0.7)

	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"message": "claude-model-router",
			"health":  "ok",
			"providers": map[string]string{
				"claude": "direct -> " + anthropicBase,
				"kimi":   kimiModel + " -> LiteLLM",
				"glm":    glmModel + " -> LiteLLM",
			},
		})
	})

	// Models listing - merges Claude models with Kimi + GLM
	mux.HandleFunc("/v1/models", func(w http.ResponseWriter, r *http.Request) {
		proxyModels(w, r, anthropicBase, kimiModel, glmModel)
	})

	// Messages endpoint - routes based on model name
	mux.HandleFunc("/v1/messages", func(w http.ResponseWriter, r *http.Request) {
		proxyMessages(w, r, anthropicBase, litellmBase, litellmKey, kimiModel, kimiMaxTokens, kimiTemp, kimiTopP, glmModel, glmMaxTokens, glmTemp, claudeTemp)
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 15 * time.Second,
		ReadTimeout:       0,  // no limit for streaming
		WriteTimeout:      0,  // no limit for streaming
		IdleTimeout:       120 * time.Second,
	}

	log.Printf("model-router listening on %s", addr)
	log.Printf("  claude -> %s (OAuth pass-through, temperature=%.2f)", anthropicBase, claudeTemp)
	log.Printf("  kimi   -> %s (model=%s, max_tokens=%d, temperature=%.2f, top_p=%.2f)", litellmBase, kimiModel, kimiMaxTokens, kimiTemp, kimiTopP)
	log.Printf("  glm    -> %s (model=%s, max_tokens=%d, temperature=%.2f)", litellmBase, glmModel, glmMaxTokens, glmTemp)
	log.Fatal(srv.ListenAndServe())
}

// --- Environment helpers ---

func envOr(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return fallback
}

func envOrInt(key string, fallback int) int {
	v := envOr(key, "")
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}

func envOrFloat(key string, fallback float64) float64 {
	v := envOr(key, "")
	if v == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return fallback
	}
	return f
}

// --- Provider detection ---

func detectProvider(model, kimiModel, glmModel string) provider {
	m := strings.ToLower(strings.TrimSpace(model))
	if m == "" {
		return providerClaude
	}

	km := strings.ToLower(strings.TrimSpace(kimiModel))
	gm := strings.ToLower(strings.TrimSpace(glmModel))

	// Exact match first
	if m == km {
		return providerKimi
	}
	if m == gm {
		return providerGLM
	}

	// Fuzzy match by keyword
	if strings.Contains(m, "kimi") || strings.Contains(m, "moonshot") {
		return providerKimi
	}
	if strings.Contains(m, "glm") {
		return providerGLM
	}

	// Default: Claude (anything starting with "claude-" or unknown)
	return providerClaude
}

// --- Message routing ---

func proxyMessages(w http.ResponseWriter, r *http.Request, anthropicBase, litellmBase, litellmKey, kimiModel string, kimiMaxTokens int, kimiTemp, kimiTopP float64, glmModel string, glmMaxTokens int, glmTemp, claudeTemp float64) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}
	_ = r.Body.Close()

	var msg messageReq
	if err := json.Unmarshal(body, &msg); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	prov := detectProvider(msg.Model, kimiModel, glmModel)

	var targetBase string
	var skipAuth bool

	switch prov {
	case providerClaude:
		// Pass through to Anthropic with original OAuth headers
		targetBase = anthropicBase
		skipAuth = false
		body = injectSettings(body, claudeTemp, 0)

	case providerKimi:
		targetBase = litellmBase
		skipAuth = true
		body = rewriteModelInBody(body, &msg, kimiModel, kimiMaxTokens)
		body = injectSettings(body, kimiTemp, kimiTopP)

	case providerGLM:
		targetBase = litellmBase
		skipAuth = true
		body = rewriteModelInBody(body, &msg, glmModel, glmMaxTokens)
		body = injectSettings(body, glmTemp, 0)
	}

	start := time.Now()
	targetURL := targetBase + r.URL.Path
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}

	upReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, targetURL, bytes.NewReader(body))
	if err != nil {
		http.Error(w, "failed to create upstream request", http.StatusInternalServerError)
		return
	}

	// Copy headers from original request
	copyHeaders(r.Header, upReq.Header, skipAuth)

	// For LiteLLM backend, inject the LiteLLM API key
	if prov != providerClaude {
		upReq.Header.Set("X-Api-Key", litellmKey)
		// Remove any OAuth headers that shouldn't go to LiteLLM
		upReq.Header.Del("Authorization")
	}

	resp, err := http.DefaultClient.Do(upReq)
	if err != nil {
		writeJSONError(w, http.StatusBadGateway, fmt.Sprintf("upstream request failed: %v", err))
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)

	log.Printf("route provider=%s model=%q stream=%v max_tokens=%d target=%s status=%d dur=%s",
		providerNames[prov], msg.Model, msg.Stream, msg.MaxTokens, targetBase, resp.StatusCode, time.Since(start).Round(time.Millisecond))
}

// rewriteModelInBody rewrites the model name, caps max_tokens, and strips
// thinking blocks from messages (external providers don't understand them).
func rewriteModelInBody(body []byte, msg *messageReq, targetModel string, maxTokensCap int) []byte {
	var raw map[string]any
	if err := json.Unmarshal(body, &raw); err != nil {
		// Fallback: byte-level replacement
		oldField := []byte(`"model":"` + msg.Model + `"`)
		newField := []byte(`"model":"` + targetModel + `"`)
		body = bytes.Replace(body, oldField, newField, 1)
		msg.Model = targetModel
		return body
	}

	raw["model"] = targetModel
	if maxTokensCap > 0 && msg.MaxTokens > maxTokensCap {
		raw["max_tokens"] = maxTokensCap
		msg.MaxTokens = maxTokensCap
	}

	// Strip thinking blocks from messages - external providers reject them
	stripThinkingBlocks(raw)

	if b, err := json.Marshal(raw); err == nil {
		body = b
		msg.Model = targetModel
	}
	return body
}

// stripThinkingBlocks removes "thinking" and "redacted_thinking" content blocks
// from all messages in the request body. Claude Code includes these in conversation
// history but external providers (Kimi, GLM) don't understand them.
func stripThinkingBlocks(raw map[string]any) {
	msgs, ok := raw["messages"].([]any)
	if !ok {
		return
	}

	for i, m := range msgs {
		msg, ok := m.(map[string]any)
		if !ok {
			continue
		}

		content, ok := msg["content"].([]any)
		if !ok {
			// content is a string, nothing to strip
			continue
		}

		filtered := make([]any, 0, len(content))
		for _, block := range content {
			bm, ok := block.(map[string]any)
			if !ok {
				filtered = append(filtered, block)
				continue
			}
			bt, _ := bm["type"].(string)
			if bt == "thinking" || bt == "redacted_thinking" {
				continue // skip thinking blocks
			}
			filtered = append(filtered, block)
		}

		// If all blocks were thinking, replace with empty text to avoid empty content
		if len(filtered) == 0 {
			filtered = append(filtered, map[string]any{
				"type": "text",
				"text": "(thinking omitted)",
			})
		}

		msg["content"] = filtered
		msgs[i] = msg
	}

	raw["messages"] = msgs
}

// injectSettings sets temperature and/or top_p in the request body.
// temperature < 0 means "don't inject" (preserve the upstream default).
// topP <= 0 means "don't inject top_p".
func injectSettings(body []byte, temperature float64, topP float64) []byte {
	if temperature < 0 && topP <= 0 {
		return body
	}
	var raw map[string]any
	if err := json.Unmarshal(body, &raw); err != nil {
		return body
	}
	if temperature >= 0 {
		raw["temperature"] = temperature
	}
	if topP > 0 {
		raw["top_p"] = topP
	}
	out, err := json.Marshal(raw)
	if err != nil {
		return body
	}
	return out
}

// --- Model listing ---

func proxyModels(w http.ResponseWriter, r *http.Request, anthropicBase, kimiModel, glmModel string) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	targetURL := anthropicBase + r.URL.Path
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}

	upReq, err := http.NewRequestWithContext(r.Context(), http.MethodGet, targetURL, nil)
	if err != nil {
		http.Error(w, "failed to create upstream request", http.StatusInternalServerError)
		return
	}
	copyHeaders(r.Header, upReq.Header, false)

	start := time.Now()
	modelsClient := &http.Client{Timeout: 3 * time.Second}
	resp, err := modelsClient.Do(upReq)
	if err != nil {
		// Anthropic unreachable - return fallback list
		fallback := fallbackModelsList(kimiModel, glmModel)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(fallback)
		log.Printf("models fallback reason=%q dur=%s", err.Error(), time.Since(start).Round(time.Millisecond))
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadGateway, "failed to read upstream models response")
		return
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		fallback := fallbackModelsList(kimiModel, glmModel)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(fallback)
		log.Printf("models fallback status=%d dur=%s", resp.StatusCode, time.Since(start).Round(time.Millisecond))
		return
	}

	// Merge external models into the Anthropic model list
	merged, added, total := appendExternalModels(body, kimiModel, glmModel)
	copyResponseHeaders(w.Header(), resp.Header)
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(merged)))
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(merged)
	log.Printf("models status=%d added_external=%v total=%d dur=%s", resp.StatusCode, added, total, time.Since(start).Round(time.Millisecond))
}

func fallbackModelsList(kimiModel, glmModel string) []byte {
	obj := map[string]any{
		"object": "list",
		"data": []map[string]any{
			modelEntry("claude-opus-4-6", "Claude Opus 4.6"),
			modelEntry("claude-sonnet-4-6", "Claude Sonnet 4.6"),
			modelEntry("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
			modelEntry(kimiModel, "Kimi K2.5"),
			modelEntry(glmModel, "GLM-5"),
		},
	}
	b, err := json.Marshal(obj)
	if err != nil {
		return []byte(`{"object":"list","data":[]}`)
	}
	return b
}

func modelEntry(id, displayName string) map[string]any {
	return map[string]any{
		"id":           id,
		"type":         "model",
		"display_name": displayName,
		"created_at":   "2026-01-01",
	}
}

func appendExternalModels(body []byte, kimiModel, glmModel string) ([]byte, bool, int) {
	var obj map[string]any
	if err := json.Unmarshal(body, &obj); err != nil {
		return body, false, 0
	}

	dataRaw, ok := obj["data"]
	if !ok {
		obj["data"] = []any{}
		dataRaw = obj["data"]
	}

	list, ok := dataRaw.([]any)
	if !ok {
		return body, false, 0
	}

	// Collect existing model IDs
	seen := map[string]bool{}
	for _, entry := range list {
		m, ok := entry.(map[string]any)
		if !ok {
			continue
		}
		if id, ok := m["id"].(string); ok {
			seen[strings.ToLower(strings.TrimSpace(id))] = true
		}
	}

	// External models to inject
	externals := []struct {
		id, name string
	}{
		{kimiModel, "Kimi K2.5"},
		{glmModel, "GLM-5"},
	}

	added := false
	for _, ext := range externals {
		if ext.id == "" {
			continue
		}
		if seen[strings.ToLower(ext.id)] {
			continue
		}
		list = append(list, modelEntry(ext.id, ext.name))
		added = true
	}

	obj["data"] = list
	out, err := json.Marshal(obj)
	if err != nil {
		return body, false, len(list)
	}
	return out, added, len(list)
}

// --- HTTP helpers ---

func copyHeaders(src, dst http.Header, skipAuth bool) {
	for k, vals := range src {
		lk := strings.ToLower(k)
		if lk == "host" || lk == "content-length" {
			continue
		}
		if skipAuth && (lk == "authorization" || lk == "x-api-key") {
			continue
		}
		for _, v := range vals {
			dst.Add(k, v)
		}
	}
}

func copyResponseHeaders(dst, src http.Header) {
	for k, vals := range src {
		lk := strings.ToLower(k)
		if lk == "content-length" || lk == "transfer-encoding" {
			continue
		}
		for _, v := range vals {
			dst.Add(k, v)
		}
	}
}

func writeJSONError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"type": "error",
		"error": map[string]any{
			"type":    "api_error",
			"message": msg,
		},
	})
}
