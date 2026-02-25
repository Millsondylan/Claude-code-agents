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
	"sync"
	"time"
)

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

type sessionRouteState struct {
	mu   sync.RWMutex
	mode map[string]string // cch -> "kimi" | "claude"
}

var routeState = &sessionRouteState{
	mode: map[string]string{},
}

func main() {
	addr := envOr("MODEL_ROUTER_ADDR", ":3001")
	anthropicBase := strings.TrimRight(envOr("ANTHROPIC_UPSTREAM_BASE", "https://api.anthropic.com"), "/")
	nvidiaBase := strings.TrimRight(envOr("NVIDIA_PROXY_URL", "http://127.0.0.1:3002"), "/")
	kimiModel := envOr("KIMI_MODEL", "moonshotai/kimi-k2.5")
	kimiAlias := envOr("KIMI_ALIAS_MODEL", "claude-kimi-k2-5")
	kimiMaxTokens := envOrInt("KIMI_MAX_TOKENS", 8192)
	kimiDisableThinking := envOrBool("KIMI_DISABLE_THINKING", true)
	kimiSmallTalkFast := envOrBool("KIMI_SMALLTALK_FAST", true)
	kimiSmallTalkMaxTokens := envOrInt("KIMI_SMALLTALK_MAX_TOKENS", 256)
	topicModel := envOr("TOPIC_DETECT_MODEL", "claude-haiku-4-5-20251001")

	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"message": "claude-model-router",
			"health":  "ok",
			"kimi":    kimiModel,
		})
	})

	mux.HandleFunc("/v1/models", func(w http.ResponseWriter, r *http.Request) {
		proxyModels(w, r, anthropicBase, kimiModel, kimiAlias)
	})

	mux.HandleFunc("/v1/messages", func(w http.ResponseWriter, r *http.Request) {
		proxyMessages(w, r, anthropicBase, nvidiaBase, kimiModel, kimiAlias, kimiMaxTokens, kimiDisableThinking, kimiSmallTalkFast, kimiSmallTalkMaxTokens, topicModel)
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 15 * time.Second,
		ReadTimeout:       0,
		WriteTimeout:      0,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("model-router listening on %s", addr)
	log.Printf("anthropic upstream: %s", anthropicBase)
	log.Printf("nvidia proxy: %s", nvidiaBase)
	log.Printf("kimi model: %s", kimiModel)
	log.Printf("kimi alias: %s", kimiAlias)
	log.Printf("kimi max_tokens cap: %d", kimiMaxTokens)
	log.Printf("kimi disable thinking: %v", kimiDisableThinking)
	log.Printf("kimi smalltalk fast mode: %v (max_tokens=%d)", kimiSmallTalkFast, kimiSmallTalkMaxTokens)
	log.Printf("topic detect model override: %s", topicModel)
	log.Fatal(srv.ListenAndServe())
}

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

func envOrBool(key string, fallback bool) bool {
	v := strings.ToLower(strings.TrimSpace(envOr(key, "")))
	if v == "" {
		return fallback
	}
	switch v {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

func isKimiModel(model, kimiModel, kimiAlias string) bool {
	m := strings.ToLower(strings.TrimSpace(model))
	km := strings.ToLower(strings.TrimSpace(kimiModel))
	ka := strings.ToLower(strings.TrimSpace(kimiAlias))
	if m == "" {
		return false
	}
	if m == km {
		return true
	}
	if ka != "" && m == ka {
		return true
	}
	return strings.Contains(m, "kimi") || strings.Contains(m, "moonshot")
}

func proxyMessages(w http.ResponseWriter, r *http.Request, anthropicBase, nvidiaBase, kimiModel, kimiAlias string, kimiMaxTokens int, kimiDisableThinking bool, kimiSmallTalkFast bool, kimiSmallTalkMaxTokens int, topicModel string) {
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
	var raw map[string]any
	if err := json.Unmarshal(body, &raw); err != nil {
		raw = nil
		log.Printf("raw-unmarshal failed, using byte rewrite path: %v", err)
	}

	// Keep internal/sub-agent traffic aligned with the currently selected /model.
	cch := extractCCH(firstSystemText(msg.Messages))
	if cch != "" {
		switch {
		case isKimiModel(msg.Model, kimiModel, kimiAlias):
			routeState.set(cch, "kimi")
		case isClaudeModel(msg.Model, kimiAlias):
			routeState.set(cch, "claude")
		}
	}

	if cch != "" && routeState.get(cch) == "kimi" && isClaudeModel(msg.Model, kimiAlias) && raw != nil {
		raw["model"] = kimiAlias
		if b, err := json.Marshal(raw); err == nil {
			body = b
			msg.Model = kimiAlias
		}
	}

	if topicModel != "" && isTopicDetectRequest(msg) && raw != nil {
		raw["model"] = topicModel
		if b, err := json.Marshal(raw); err == nil {
			body = b
			msg.Model = topicModel
		}
	}

	targetBase := anthropicBase
	skipAuth := false
	if isKimiModel(msg.Model, kimiModel, kimiAlias) {
		// Always send NVIDIA the real provider model id.
		if raw != nil {
			raw["model"] = kimiModel
			if kimiDisableThinking {
				chatTemplateKwargs, _ := raw["chat_template_kwargs"].(map[string]any)
				if chatTemplateKwargs == nil {
					chatTemplateKwargs = map[string]any{}
				}
				if _, hasThinking := chatTemplateKwargs["thinking"]; !hasThinking {
					chatTemplateKwargs["thinking"] = false
				}
				raw["chat_template_kwargs"] = chatTemplateKwargs
			}
			if kimiSmallTalkFast && isLikelySmallTalk(latestUserText(msg.Messages)) {
				if _, hasTools := raw["tools"]; hasTools {
					raw["tools"] = []any{}
				}
				if kimiSmallTalkMaxTokens > 0 && msg.MaxTokens > kimiSmallTalkMaxTokens {
					raw["max_tokens"] = kimiSmallTalkMaxTokens
					msg.MaxTokens = kimiSmallTalkMaxTokens
				}
			}
			if b, err := json.Marshal(raw); err == nil {
				body = b
				msg.Model = kimiModel
			}
		} else {
			oldModel := msg.Model
			oldField := []byte(`"model":"` + oldModel + `"`)
			newField := []byte(`"model":"` + kimiModel + `"`)
			body = bytes.Replace(body, oldField, newField, 1)
			msg.Model = kimiModel
		}
		if short, text := shouldShortCircuitKimi(msg); short {
			writeSyntheticTextResponse(w, msg.Model, text)
			return
		}
		if kimiMaxTokens > 0 && msg.MaxTokens > kimiMaxTokens && raw != nil {
			raw["max_tokens"] = kimiMaxTokens
			if b, err := json.Marshal(raw); err == nil {
				body = b
				msg.MaxTokens = kimiMaxTokens
			}
		}
		targetBase = nvidiaBase
		skipAuth = true
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

	copyHeaders(r.Header, upReq.Header, skipAuth)

	resp, err := http.DefaultClient.Do(upReq)
	if err != nil {
		writeJSONError(w, http.StatusBadGateway, fmt.Sprintf("upstream request failed: %v", err))
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
	log.Printf("route model=%q stream=%v max_tokens=%d target=%s status=%d dur=%s", msg.Model, msg.Stream, msg.MaxTokens, targetBase, resp.StatusCode, time.Since(start).Round(time.Millisecond))
}

func proxyModels(w http.ResponseWriter, r *http.Request, anthropicBase, kimiModel, kimiAlias string) {
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
	modelsClient := &http.Client{Timeout: 2 * time.Second}
	resp, err := modelsClient.Do(upReq)
	if err != nil {
		fallback := fallbackModelsList(kimiModel, kimiAlias)
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
		fallback := fallbackModelsList(kimiModel, kimiAlias)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(fallback)
		log.Printf("models fallback status=%d dur=%s", resp.StatusCode, time.Since(start).Round(time.Millisecond))
		return
	}

	merged, added, total := appendRequiredModels(body, kimiModel, kimiAlias)
	copyResponseHeaders(w.Header(), resp.Header)
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(merged)))
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(merged)
	log.Printf("models status=%d added_required=%v total=%d dur=%s", resp.StatusCode, added, total, time.Since(start).Round(time.Millisecond))
}

func fallbackModelsList(kimiModel, kimiAlias string) []byte {
	kimiPickerID := kimiAlias
	if strings.TrimSpace(kimiPickerID) == "" {
		kimiPickerID = kimiModel
	}
	obj := map[string]any{
		"object": "list",
		"data": []map[string]any{
			{
				"id":           "claude-sonnet-4-6",
				"type":         "model",
				"display_name": "Claude Sonnet 4.6",
				"created_at":   "2026-01-01",
			},
			{
				"id":           "claude-opus-4-6",
				"type":         "model",
				"display_name": "Claude Opus 4.6",
				"created_at":   "2026-01-01",
			},
			{
				"id":           "claude-haiku-4-5-20251001",
				"type":         "model",
				"display_name": "Claude Haiku 4.5",
				"created_at":   "2026-01-01",
			},
			{
				"id":           kimiPickerID,
				"type":         "model",
				"display_name": "Kimi K2.5",
				"created_at":   "2026-01-01",
			},
			{
				"id":           kimiModel,
				"type":         "model",
				"display_name": "Kimi K2.5 (Direct ID)",
				"created_at":   "2026-01-01",
			},
		},
	}
	b, err := json.Marshal(obj)
	if err != nil {
		return []byte(`{"object":"list","data":[]}`)
	}
	return b
}

func appendRequiredModels(body []byte, kimiModel, kimiAlias string) ([]byte, bool, int) {
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

	total := len(list)
	required := []string{
		"claude-sonnet-4-6",
		"claude-opus-4-6",
		"claude-haiku-4-5-20251001",
		kimiModel,
	}
	if strings.TrimSpace(kimiAlias) != "" {
		required = append(required, kimiAlias)
	}

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

	// Copy the shape of an existing model object when available to maximize compatibility.
	template := map[string]any{}
	if len(list) > 0 {
		if first, ok := list[0].(map[string]any); ok {
			for k, v := range first {
				template[k] = v
			}
		}
	}

	added := false
	for _, reqID := range required {
		reqID = strings.TrimSpace(reqID)
		if reqID == "" {
			continue
		}
		if seen[strings.ToLower(reqID)] {
			continue
		}
		entry := map[string]any{}
		for k, v := range template {
			entry[k] = v
		}
		entry["id"] = reqID
		entry["type"] = "model"
		entry["display_name"] = displayNameFor(reqID, kimiModel, kimiAlias)
		if _, ok := entry["created_at"]; !ok {
			entry["created_at"] = "2026-01-01"
		}
		list = append(list, entry)
		added = true
	}
	obj["data"] = list

	out, err := json.Marshal(obj)
	if err != nil {
		return body, false, total
	}
	return out, added, len(list)
}

func displayNameFor(id, kimiModel, kimiAlias string) string {
	switch strings.TrimSpace(id) {
	case "claude-opus-4-6":
		return "Claude Opus 4.6"
	case "claude-sonnet-4-6":
		return "Claude Sonnet 4.6"
	case "claude-haiku-4-5-20251001":
		return "Claude Haiku 4.5"
	default:
		if strings.EqualFold(strings.TrimSpace(id), strings.TrimSpace(kimiModel)) ||
			(strings.TrimSpace(kimiAlias) != "" && strings.EqualFold(strings.TrimSpace(id), strings.TrimSpace(kimiAlias))) ||
			strings.Contains(strings.ToLower(id), "kimi") {
			return "Kimi K2.5"
		}
		return id
	}
}

func isClaudeModel(model, kimiAlias string) bool {
	m := strings.ToLower(strings.TrimSpace(model))
	if m == "" {
		return false
	}
	if strings.TrimSpace(kimiAlias) != "" && m == strings.ToLower(strings.TrimSpace(kimiAlias)) {
		return false
	}
	return strings.HasPrefix(m, "claude-")
}

func (s *sessionRouteState) set(cch, mode string) {
	if cch == "" || mode == "" {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.mode) > 2000 {
		s.mode = map[string]string{}
	}
	s.mode[cch] = mode
}

func (s *sessionRouteState) get(cch string) string {
	if cch == "" {
		return ""
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.mode[cch]
}

func extractCCH(systemText string) string {
	s := strings.TrimSpace(systemText)
	if s == "" {
		return ""
	}
	idx := strings.Index(s, "cch=")
	if idx < 0 {
		return ""
	}
	rest := s[idx+4:]
	end := strings.Index(rest, ";")
	if end < 0 {
		end = len(rest)
	}
	cch := strings.TrimSpace(rest[:end])
	if cch == "" {
		return ""
	}
	valid := true
	for _, r := range cch {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			continue
		}
		valid = false
		break
	}
	if !valid {
		return ""
	}
	return cch
}

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

func shouldShortCircuitKimi(req messageReq) (bool, string) {
	if req.Stream {
		return false, ""
	}
	if req.MaxTokens > 1 {
		return false, ""
	}
	text := strings.ToLower(strings.TrimSpace(firstUserText(req.Messages)))
	switch text {
	case "count", "quota":
		return true, "1"
	default:
		return false, ""
	}
}

func firstUserText(msgs []anthropicMsg) string {
	for _, m := range msgs {
		if strings.ToLower(strings.TrimSpace(m.Role)) != "user" {
			continue
		}
		switch c := m.Content.(type) {
		case string:
			return c
		case []any:
			for _, block := range c {
				bm, ok := block.(map[string]any)
				if !ok {
					continue
				}
				bt, _ := bm["type"].(string)
				if bt != "text" {
					continue
				}
				if t, ok := bm["text"].(string); ok {
					return t
				}
			}
		}
	}
	return ""
}

func latestUserText(msgs []anthropicMsg) string {
	for i := len(msgs) - 1; i >= 0; i-- {
		m := msgs[i]
		if strings.ToLower(strings.TrimSpace(m.Role)) != "user" {
			continue
		}
		switch c := m.Content.(type) {
		case string:
			return c
		case []any:
			for _, block := range c {
				bm, ok := block.(map[string]any)
				if !ok {
					continue
				}
				bt, _ := bm["type"].(string)
				if bt != "text" {
					continue
				}
				if t, ok := bm["text"].(string); ok {
					return t
				}
			}
		}
	}
	return ""
}

func isLikelySmallTalk(text string) bool {
	s := strings.ToLower(strings.TrimSpace(text))
	if s == "" {
		return false
	}
	if len([]rune(s)) > 120 {
		return false
	}
	codingHints := []string{
		"code", "bug", "error", "stack", "trace", "fix", "refactor", "test", "build",
		"compile", "npm", "yarn", "pnpm", "pip", "cargo", "go ", "rust", "python",
		"javascript", "typescript", "file", "function", "class", "api", "endpoint",
		"deploy", "database", "sql", "regex", "script", "terminal", "command",
	}
	for _, h := range codingHints {
		if strings.Contains(s, h) {
			return false
		}
	}
	smallTalkHints := []string{
		"yo", "hi", "hello", "hey", "sup", "what model", "who are you",
		"how are you", "what's up", "whats up", "idk", "thanks",
	}
	for _, h := range smallTalkHints {
		if strings.Contains(s, h) {
			return true
		}
	}
	return len(strings.Fields(s)) <= 8
}

func firstSystemText(msgs []anthropicMsg) string {
	for _, m := range msgs {
		if strings.ToLower(strings.TrimSpace(m.Role)) != "system" {
			continue
		}
		switch c := m.Content.(type) {
		case string:
			return c
		case []any:
			for _, block := range c {
				bm, ok := block.(map[string]any)
				if !ok {
					continue
				}
				bt, _ := bm["type"].(string)
				if bt != "text" {
					continue
				}
				if t, ok := bm["text"].(string); ok {
					return t
				}
			}
		}
	}
	return ""
}

func isTopicDetectRequest(req messageReq) bool {
	if len(req.Messages) == 0 {
		return false
	}
	systemText := strings.ToLower(firstSystemText(req.Messages))
	if systemText == "" {
		return false
	}
	return strings.Contains(systemText, "analyze if this message indicates a new conversation topic")
}

func writeSyntheticTextResponse(w http.ResponseWriter, model, text string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"id":            fmt.Sprintf("msg_local_%d", time.Now().UnixNano()),
		"type":          "message",
		"role":          "assistant",
		"model":         model,
		"content":       []map[string]any{{"type": "text", "text": text}},
		"stop_reason":   "end_turn",
		"stop_sequence": nil,
		"usage": map[string]any{
			"input_tokens":  1,
			"output_tokens": 1,
		},
	})
}
