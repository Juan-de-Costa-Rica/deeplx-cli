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
			{
				Name:  "setup",
				Usage: "Interactive setup for DeepLX CLI",
				Action: func(c *cli.Context) error {
					fmt.Println("🚀 DeepLX CLI Setup")
					fmt.Println("==================")
					fmt.Println()
					
					// Check if DeepLX is running locally
					fmt.Print("Checking for local DeepLX server... ")
					localURL := "http://localhost:1188"
					if err := checkServerConnection(localURL, 5*time.Second); err == nil {
						fmt.Println("✓ Found!")
						
						// Test if it requires authentication
						_, err := translate(localURL, "test", "AUTO", "EN", "", 5*time.Second, false)
						if err != nil && strings.Contains(err.Error(), "authentication") {
							fmt.Println("\n⚠️  Server requires authentication")
							fmt.Print("Enter your token (or press Enter to skip): ")
							var token string
							fmt.Scanln(&token)
							
							if token != "" {
								// Test with token
								_, err = translate(localURL, "test", "AUTO", "EN", token, 5*time.Second, false)
								if err == nil {
									// Save configuration
									config := Config{
										DefaultURL:   localURL,
										DefaultToken: token,
									}
									if err := saveConfig(config); err == nil {
										fmt.Println("\n✓ Configuration saved!")
										fmt.Println("\nYou're all set! Try:")
										fmt.Println(`  translate "Hello world"`)
										return nil
									}
								} else {
									fmt.Println("⚠️  Token verification failed:", err)
								}
							}
						} else if err == nil {
							// No authentication needed
							config := Config{
								DefaultURL: localURL,
							}
							if err := saveConfig(config); err == nil {
								fmt.Println("\n✓ Configuration saved!")
								fmt.Println("\nYou're all set! Try:")
								fmt.Println(`  translate "Hello world"`)
								return nil
							}
						}
					} else {
						fmt.Println("✗ Not found")
					}
					
					// Offer to start DeepLX with Docker
					fmt.Println("\n📦 No local DeepLX server found.")
					fmt.Println("\nWould you like to:")
					fmt.Println("1. Start DeepLX with Docker (recommended)")
					fmt.Println("2. Use a remote DeepLX server")
					fmt.Println("3. Exit and set up manually")
					fmt.Print("\nChoice (1-3): ")
					
					var choice string
					fmt.Scanln(&choice)
					
					switch choice {
					case "1":
						fmt.Println("\nTo start DeepLX with Docker, run:")
						fmt.Println("\n  docker run -d -p 1188:1188 ghcr.io/owo-network/deeplx:latest")
						fmt.Println("\nThen run 'translate setup' again.")
						
					case "2":
						fmt.Print("\nEnter the DeepLX server URL: ")
						var serverURL string
						fmt.Scanln(&serverURL)
						
						if serverURL != "" {
							// Test connection
							fmt.Print("Testing connection... ")
							if err := checkServerConnection(serverURL, 10*time.Second); err != nil {
								fmt.Println("✗ Failed")
								fmt.Println("Error:", err)
								return nil
							}
							fmt.Println("✓ Connected")
							
							// Check if authentication is needed
							fmt.Print("\nDoes this server require authentication? (y/N): ")
							var needsAuth string
							fmt.Scanln(&needsAuth)
							
							var token string
							if strings.ToLower(needsAuth) == "y" {
								fmt.Print("Enter your token: ")
								fmt.Scanln(&token)
							}
							
							// Test translation
							fmt.Print("\nTesting translation... ")
							result, err := translate(serverURL, "Hello", "AUTO", "EN", token, 10*time.Second, false)
							if err != nil {
								fmt.Println("✗ Failed")
								fmt.Println("Error:", err)
								return nil
							}
							fmt.Printf("✓ Success! Got: %s\n", result.Data)
							
							// Save configuration
							config := Config{
								DefaultURL:   serverURL,
								DefaultToken: token,
							}
							if err := saveConfig(config); err != nil {
								fmt.Println("\n⚠️  Failed to save config:", err)
								return nil
							}
							
							fmt.Println("\n✓ Configuration saved!")
							fmt.Println("\nYou're all set! Try:")
							fmt.Println(`  translate "Hello world"`)
						}
						
					case "3":
						fmt.Println("\nTo set up manually:")
						fmt.Println("1. Start a DeepLX server")
						fmt.Println("2. Configure with: translate config set --url <server-url>")
						fmt.Println("3. If needed, add: --token <your-token>")
					}
					
					return nil
				},
			},
			{
				Name:  "doctor",
				Usage: "Diagnose configuration and connection issues",
				Action: func(c *cli.Context) error {
					fmt.Println("🔍 DeepLX CLI Diagnostic")
					fmt.Println("=======================")
					fmt.Println()
					
					// Check configuration
					config := loadConfig()
					fmt.Println("Configuration:")
					if config.DefaultURL != "" {
						fmt.Printf("  ✓ Default URL: %s\n", config.DefaultURL)
					} else {
						fmt.Printf("  ✗ Default URL: not set (using http://localhost:1188)\n")
					}
					
					if config.DefaultToken != "" {
						fmt.Printf("  ✓ Default Token: configured\n")
					} else {
						fmt.Printf("  ℹ Default Token: not set\n")
					}
					
					// Check environment variables
					fmt.Println("\nEnvironment:")
					if token := os.Getenv("TOKEN"); token != "" {
						fmt.Printf("  ✓ TOKEN: set\n")
					} else if token := os.Getenv("DEEPLX_TOKEN"); token != "" {
						fmt.Printf("  ✓ DEEPLX_TOKEN: set\n")
					} else {
						fmt.Printf("  ℹ No token in environment\n")
					}
					
					if url := os.Getenv("DEEPLX_URL"); url != "" {
						fmt.Printf("  ✓ DEEPLX_URL: %s\n", url)
					}
					
					// Test connection
					serverURL := c.String("url")
					if serverURL == "" {
						serverURL = config.DefaultURL
						if serverURL == "" {
							serverURL = "http://localhost:1188"
						}
					}
					
					fmt.Printf("\nTesting connection to %s:\n", serverURL)
					
					// Check if reachable
					fmt.Print("  Checking connectivity... ")
					if err := checkServerConnection(serverURL, 5*time.Second); err != nil {
						fmt.Println("✗ Failed")
						fmt.Printf("  Error: %v\n", err)
						return nil
					}
					fmt.Println("✓ OK")
					
					// Try a test translation
					token := c.String("token")
					if token == "" {
						token = config.DefaultToken
					}
					
					fmt.Print("  Testing translation... ")
					result, err := translate(serverURL, "Hello", "AUTO", "EN", token, 5*time.Second, false)
					if err != nil {
						fmt.Println("✗ Failed")
						fmt.Printf("  Error: %v\n", err)
						
						if strings.Contains(err.Error(), "authentication") {
							fmt.Println("\n💡 Tip: This server requires authentication.")
							fmt.Println("   Set a token with: translate config set --token <your-token>")
						}
					} else {
						fmt.Printf("✓ OK (got: %s)\n", result.Data)
						fmt.Printf("  Method: %s\n", result.Method)
						fmt.Printf("  Source: %s\n", result.SourceLang)
					}
					
					return nil
				},
			},	
			
		},
		// Replace the Action function in main() with this enhanced version
		Action: func(c *cli.Context) error {
			if c.NArg() == 0 {
				// Check if this might be a first run
				config := loadConfig()
				if config.DefaultURL == "" && config.DefaultToken == "" {
					// No configuration found, suggest setup
					fmt.Println("👋 Welcome to DeepLX CLI!")
					fmt.Println("\nIt looks like this is your first time using the tool.")
					fmt.Println("Let's get you set up:")
					fmt.Println("\n  translate setup")
					fmt.Println("\nOr see all available commands:")
					fmt.Println("\n  translate --help")
					return nil
				}
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
				// Check if it's a connection error and provide helpful guidance
				if strings.Contains(err.Error(), "cannot connect to DeepLX server") {
					fmt.Fprintln(os.Stderr, err)
					fmt.Fprintln(os.Stderr, "\n💡 First time? Run: translate setup")
					return cli.Exit("", 1)
				}
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
	// First, check if the server is reachable
	if err := checkServerConnection(serverURL, timeout); err != nil {
		return nil, err
	}

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
		// Check if it's a connection error
		if strings.Contains(err.Error(), "connection refused") || strings.Contains(err.Error(), "dial tcp") {
			return nil, fmt.Errorf(`cannot connect to DeepLX server at %s

It looks like DeepLX is not running. To fix this:

1. Start DeepLX with Docker:
   docker run -d -p 1188:1188 ghcr.io/owo-network/deeplx:latest

2. Or use a different server:
   translate --url https://your-server.com "Hello world"

3. Or configure a default server:
   translate config set --url https://your-server.com

For more info: https://github.com/OwO-Network/DeepLX`, serverURL)
		}
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

// checkServerConnection checks if the DeepLX server is reachable
func checkServerConnection(serverURL string, timeout time.Duration) error {
	client := &http.Client{
		Timeout: timeout,
	}
	
	// Try to reach the root endpoint
	resp, err := client.Get(serverURL)
	if err != nil {
		if strings.Contains(err.Error(), "connection refused") || strings.Contains(err.Error(), "dial tcp") {
			return fmt.Errorf(`cannot connect to DeepLX server at %s

No DeepLX server found. To start one:

  docker run -d -p 1188:1188 ghcr.io/owo-network/deeplx:latest

Or specify a different server:

  translate --url https://your-server.com "Hello world"`, serverURL)
		}
		return fmt.Errorf("server not reachable at %s: %v", serverURL, err)
	}
	defer resp.Body.Close()
	
	return nil
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
		fmt.Printf("  Default T0ken: [not set]\n")
	}
	
	return nil
}
