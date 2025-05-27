package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/urfave/cli/v2"
)

// Version information
const (
	AppName    = "translate"
	AppVersion = "0.1.0"
)

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
				Value:   "http://localhost:1188",
				Usage:   "DeepLX server URL",
			},
			&cli.BoolFlag{
				Name:    "alternatives",
				Aliases: []string{"a"},
				Value:   false,
				Usage:   "Show alternative translations",
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
			showAlternatives := c.Bool("alternatives")

			result, err := translate(serverURL, text, sourceLang, targetLang)
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
func translate(serverURL, text, sourceLang, targetLang string) (*TranslationResponse, error) {
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

	// Create HTTP request
	req, err := http.NewRequest("POST", fmt.Sprintf("%s/translate", serverURL), bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")

	// Send request
	client := &http.Client{}
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

	// Check status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status %d: %s", resp.StatusCode, string(body))
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
