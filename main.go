package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/urfave/cli/v2"
)

// Version information
const (
	AppName    = "translate"
	AppVersion = "0.1.0"
)

// Config represents the configuration file structure
type Config struct {
	DefaultURL   string `json:"default_url,omitempty"`
	DefaultToken string `json:"default_token,omitempty"`
}

// Response from DeepLX API
type TranslationResponse struct {
	Code         int      `json:"code"`
	ID           int64    `json:"id"`
	Data         string   `json:"data"`
	Alternatives []string `json:"alternatives"`
	SourceLang   string   `json:"source_lang"`
	TargetLang   string   `json:"target_lang"`
	Method       string   `json:"method"`
}

// Request to DeepLX API
type TranslationRequest struct {
	Text       string `json:"text"`
	SourceLang string `json:"source_lang"`
	TargetLang string `json:"target_lang"`
}

func main() {
	// Load configuration
	config := loadConfig()

	// Set defaults from config
	defaultURL := "http://localhost:1188"
	if config.DefaultURL != "" {
		defaultURL = config.DefaultURL
	}

	defaultToken := ""
	if config.DefaultToken != "" {
		defaultToken = config.DefaultToken
	}

	app := &cli.App{
		Name:    AppName,
		Version: AppVersion,
		Usage:   "A simple CLI for translating text using DeepLX",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "source",
				Aliases: []string{"s"},
				Value:   "auto",
				Usage:   "Source language code (e.g., en, fr, es, auto for automatic detection)",
			},
			&cli.StringFlag{
				Name:    "target",
				Aliases: []string{"t"},
				Value:   "en",
				Usage:   "Target language code (e.g., en, fr, es)",
			},
			&cli.StringFlag{
				Name:    "url",
				Aliases: []string{"u"},
				Value:   defaultURL,
				Usage:   "DeepLX server URL",
				EnvVars: []string{"DEEPLX_URL"},
			},
			&cli.StringFlag{
				Name:    "token",
				Aliases: []string{"k"},
				Value:   defaultToken,
				Usage:   "Authentication token for DeepLX server",
				EnvVars: []string{"TOKEN", "DEEPLX_TOKEN"},
			},
			&cli.BoolFlag{
				Name:    "alternatives",
				Aliases: []string{"a"},
				Value:   false,
				Usage:   "Show alternative translations",
			},
			&cli.IntFlag{
				Name:    "timeout",
				Value:   30,
				Usage:   "Request timeout in seconds",
			},
			&cli.BoolFlag{
				Name:  "debug",
				Value: false,
				Usage: "Enable debug output",
			},
		},
		Commands: []*cli.Command{
			{
				Name:  "config",
				Usage: "Configure default settings",
				Subcommands: []*cli.Command{
					{
						Name:  "set",
						Usage: "Set a configuration value",
						Flags: []cli.Flag{
							&cli.StringFlag{
								Name:  "url",
								Usage: "Set default DeepLX server URL",
							},
							&cli.StringFlag{
								Name:  "token", 
								Usage: "Set default authentication token",
							},
						},
						Action: func(c *cli.Context) error {
							return setConfig(c)
						},
					},
					{
						Name:  "show",
						Usage: "Show current configuration",
						Action: func(c *cli.Context) error {
							return showConfig()
						},
					},
				},
			},
		},
		Action: func(c *cli.Context) error {
			if c.NArg() == 0 {
				return cli.ShowAppHelp(c)
			}

			text := strings.Join(c.Args().Slice(), " ")
			sourceLang := strings.ToUpper(c.String("source"))
			targetLang := strings.ToUpper(c.String("target"))
			serverURL := c.String("url")
			token := c.String("token")
			showAlternatives := c.Bool("alternatives")
			timeout := time.Duration(c.Int("timeout")) * time.Second
			debug := c.Bool("debug")

			if debug {
				fmt.Fprintf(os.Stderr, "Debug: URL=%s, Source=%s, Target=%s, HasToken=%t\n", 
					serverURL, sourceLang, targetLang, token != "")
			}

			result, err := translate(serverURL, text, sourceLang, targetLang, token, timeout, debug)
			if err != nil {
				return cli.Exit(fmt.Sprintf("Translation error: %s", err), 1)
			}

			// Print the translation
			fmt.Println(result.Data)

			// Print alternatives if requested
			if showAlternatives && len(result.Alternatives) > 0 {
				fmt.Println("\nAlternatives:")
				for i, alt := range result.Alternatives {
					fmt.Printf("%d. %s\n", i+1, alt)
				}
			}

			// Print metadata in debug mode
			if debug {
				fmt.Fprintf(os.Stderr, "Debug: Method=%s, SourceLang=%s, ID=%d\n", 
					result.Method, result.SourceLang, result.ID)
			}

			return nil
		},
	}

	err := app.Run(os.Args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s\n", err)
		os.Exit(1)
	}
}

// translate sends a translation request to the DeepLX server
func translate(serverURL, text, sourceLang, targetLang, token string, timeout time.Duration, debug bool) (*TranslationResponse, error) {
	// Create request body
	reqBody := TranslationRequest{
		Text:       text,
		SourceLang: sourceLang,
		TargetLang: targetLang,
	}

	// Convert request body to JSON
	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %v", err)
	}

	if debug {
		fmt.Fprintf(os.Stderr, "Debug: Request body: %s\n", string(jsonData))
	}

	// Create HTTP request
	req, err := http.NewRequest("POST", fmt.Sprintf("%s/translate", serverURL), bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", fmt.Sprintf("%s/%s", AppName, AppVersion))
	
	// Add authentication if token is provided
	if token != "" {
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))
		if debug {
			fmt.Fprintf(os.Stderr, "Debug: Using token authentication\n")
		}
	} else if debug {
		fmt.Fprintf(os.Stderr, "Debug: No token provided\n")
	}

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: timeout,
	}

	// Send request
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %v", err)
	}

	if debug {
		fmt.Fprintf(os.Stderr, "Debug: Response status: %d\n", resp.StatusCode)
		fmt.Fprintf(os.Stderr, "Debug: Response body: %s\n", string(body))
	}

	// Check status code and provide helpful error messages
	if resp.StatusCode != http.StatusOK {
		switch resp.StatusCode {
		case http.StatusUnauthorized:
			return nil, fmt.Errorf("authentication failed - check your token")
		case http.StatusTooManyRequests:
			return nil, fmt.Errorf("rate limit exceeded - please wait and try again")
		case http.StatusNotFound:
			return nil, fmt.Errorf("server endpoint not found - check your URL: %s", serverURL)
		default:
			return nil, fmt.Errorf("server returned status %d: %s", resp.StatusCode, string(body))
		}
	}

	// Parse response
	var result TranslationResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse response: %v", err)
	}

	// Check if translation was successful
	if result.Code != http.StatusOK {
		return nil, fmt.Errorf("translation failed with code %d: %s", result.Code, result.Data)
	}

	return &result, nil
}

// loadConfig loads configuration from ~/.config/translate/config.json
func loadConfig() Config {
	var config Config
	
	configDir, err := os.UserConfigDir()
	if err != nil {
		return config
	}
	
	configPath := filepath.Join(configDir, "translate", "config.json")
	
	data, err := os.ReadFile(configPath)
	if err != nil {
		return config
	}
	
	json.Unmarshal(data, &config)
	return config
}

// saveConfig saves configuration to ~/.config/translate/config.json
func saveConfig(config Config) error {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return err
	}
	
	translateConfigDir := filepath.Join(configDir, "translate")
	if err := os.MkdirAll(translateConfigDir, 0755); err != nil {
		return err
	}
	
	configPath := filepath.Join(translateConfigDir, "config.json")
	
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	
	return os.WriteFile(configPath, data, 0644)
}

// setConfig handles the config set command
func setConfig(c *cli.Context) error {
	config := loadConfig()
	
	if url := c.String("url"); url != "" {
		config.DefaultURL = url
		fmt.Printf("Set default URL to: %s\n", url)
	}
	
	if token := c.String("token"); token != "" {
		config.DefaultToken = token
		fmt.Printf("Set default token\n")
	}
	
	return saveConfig(config)
}

// showConfig handles the config show command
func showConfig() error {
	config := loadConfig()
	
	fmt.Printf("Current configuration:\n")
	fmt.Printf("  Default URL: %s\n", config.DefaultURL)
	if config.DefaultToken != "" {
		fmt.Printf("  Default Token: [configured]\n")
	} else {
		fmt.Printf("  Default Token: [not set]\n")
	}
	
	return nil
}
