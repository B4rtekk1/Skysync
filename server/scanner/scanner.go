package scanner

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"skysync/global"
	"strings"
	"time"
)

type HeuristicRule struct {
	Name        string
	Description string
	Matcher     func(filePath string, content []byte) (bool, float64, error)
}

type Scanner struct {
	Rules            []HeuristicRule
	MaxWorkers       int
	Verbose          bool
	ReportChan       chan string
	EntropyThreshold float64
	Timeout          time.Duration
}

func NewScanner() *Scanner {
	verbose := false
	entropyThreshold := 8.2
	timeout := 30 * time.Second

	if global.AppConfig != nil {
		verbose = global.AppConfig.Scanner.Verbose
		if global.AppConfig.Scanner.EntropyThreshold > 0 {
			entropyThreshold = global.AppConfig.Scanner.EntropyThreshold
		}
		if global.AppConfig.FileScanTimeout > 0 {
			timeout = time.Duration(global.AppConfig.FileScanTimeout) * time.Second
		}
	}

	sc := &Scanner{
		MaxWorkers:       runtime.NumCPU() * 2,
		ReportChan:       make(chan string, 1000),
		Verbose:          verbose,
		EntropyThreshold: entropyThreshold,
		Timeout:          timeout,
	}

	sc.Rules = []HeuristicRule{
		{
			Name:        "ExecutableHeader",
			Description: "Checks for PE/ELF executable headers",
			Matcher:     sc.checkExecutableHeader,
		},
		{
			Name:        "SuspiciousStrings",
			Description: "Searches for known suspicious strings",
			Matcher:     sc.checkSuspiciousStrings,
		},
		{
			Name:        "HighEntropy",
			Description: "Detects high entropy files",
			Matcher:     sc.checkHighEntropy,
		},
		{
			Name:        "KnownMalwareHash",
			Description: "Matches against known malware hashes",
			Matcher:     sc.checkKnownMalwareHash,
		},
		{
			Name:        "RegexPatterns",
			Description: "Matches known malicious regex patterns",
			Matcher:     sc.checkRegexPatterns,
		},
		{
			Name:        "MP4Header",
			Description: "Checks for MP4 file header and non-standard brands",
			Matcher:     sc.checkMP4Header,
		},
	}
	return sc
}

func (s *Scanner) ScanFile(path string) error {
	ctx, cancel := context.WithTimeout(context.Background(), s.Timeout)
	defer cancel()

	resultChan := make(chan error, 1)

	go func() {
		content, err := os.ReadFile(path)
		if err != nil {
			resultChan <- fmt.Errorf("failed to read file %s: %v", path, err)
			return
		}

		ext := strings.ToLower(filepath.Ext(path))
		var detections []string
		var entropyDetails string

		for _, rule := range s.Rules {
			select {
			case <-ctx.Done():
				return
			default:
			}

			if rule.Name == "HighEntropy" && isCompressedFormat(ext) {
				continue
			}
			if rule.Name == "SuspiciousStrings" && !isTextOrScriptFormat(ext) {
				continue
			}
			if rule.Name == "MP4Header" && ext != ".mp4" {
				continue
			}

			match, entropy, err := rule.Matcher(path, content)
			if err != nil {
				if s.Verbose {
					log.Printf("Error applying rule %s on file %s: %v", rule.Name, path, err)
				}
				continue
			}
			if match {
				if rule.Name == "HighEntropy" {
					detections = append(detections, fmt.Sprintf("%s (entropy: %.2f)", rule.Name, entropy))
					entropyDetails = fmt.Sprintf("entropy: %.2f", entropy)
				} else {
					detections = append(detections, rule.Name)
				}
			}
		}

		if len(detections) > 0 {
			report := fmt.Sprintf("Suspicious file detected: %s | Rules: %s", path, strings.Join(detections, ", "))
			s.ReportChan <- report
			if s.Verbose {
				log.Printf("%s", report)
			}
			if entropyDetails != "" {
				resultChan <- fmt.Errorf("malware detected in file %s: triggered rules: %s (%s)", path, strings.Join(detections, ", "), entropyDetails)
				return
			}
			resultChan <- fmt.Errorf("malware detected in file %s: triggered rules: %s", path, strings.Join(detections, ", "))
			return
		}

		if s.Verbose {
			report := fmt.Sprintf("Clean file: %s", path)
			s.ReportChan <- report
			log.Printf("%s", report)
		}
		resultChan <- nil
	}()

	select {
	case err := <-resultChan:
		return err
	case <-ctx.Done():
		return fmt.Errorf("scan timed out for file %s", path)
	}
}

func isCompressedFormat(ext string) bool {
	compressedExtensions := []string{".mp4", ".avi", ".mkv", ".jpg", ".jpeg", ".png", ".zip", ".rar", ".gz"}
	for _, e := range compressedExtensions {
		if ext == e {
			return true
		}
	}
	return false
}

func isTextOrScriptFormat(ext string) bool {
	textExtensions := []string{".txt", ".js", ".vbs", ".py", ".html", ".xml", ".json"}
	for _, e := range textExtensions {
		if ext == e {
			return true
		}
	}
	return false
}

func (s *Scanner) checkExecutableHeader(_ string, content []byte) (bool, float64, error) {
	if len(content) < 4 {
		return false, 0, nil
	}
	if content[0] == 'M' && content[1] == 'Z' {
		return true, 0, nil
	}
	if content[0] == 0x7f && content[1] == 'E' && content[2] == 'L' && content[3] == 'F' {
		return true, 0, nil
	}
	return false, 0, nil
}

func (s *Scanner) checkSuspiciousStrings(_ string, content []byte) (bool, float64, error) {
	scanner := bufio.NewScanner(strings.NewReader(string(content)))
	suspicious := []string{"virus", "malware", "trojan", "exploit", "backdoor", "ransomware", "keylogger", "payload", "shellcode"}
	for scanner.Scan() {
		line := strings.ToLower(scanner.Text())
		for _, word := range suspicious {
			if strings.Contains(line, word) {
				return true, 0, nil
			}
		}
	}
	return false, 0, nil
}

func (s *Scanner) checkHighEntropy(_ string, content []byte) (bool, float64, error) {
	if len(content) == 0 {
		return false, 0, nil
	}
	freq := make(map[byte]float64)
	for _, b := range content {
		freq[b]++
	}
	var entropy float64
	for _, count := range freq {
		p := count / float64(len(content))
		entropy -= p * math.Log2(p)
	}
	return entropy >= s.EntropyThreshold, entropy, nil
}

func (s *Scanner) checkKnownMalwareHash(_ string, content []byte) (bool, float64, error) {
	hash := sha256.Sum256(content)
	hexHash := hex.EncodeToString(hash[:])
	knownHashes := []string{
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
	}
	for _, kh := range knownHashes {
		if hexHash == kh {
			return true, 0, nil
		}
	}
	return false, 0, nil
}

func (s *Scanner) checkRegexPatterns(_ string, content []byte) (bool, float64, error) {
	patterns := []string{
		`https?://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(?:\:[0-9]+)?(?:/[^\s]*)?(?:malware|phishing|exploit)`,
		`\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b`,
	}
	for _, pat := range patterns {
		re, err := regexp.Compile(pat)
		if err != nil {
			log.Printf("Failed to compile regex %s: %v", pat, err)
			return false, 0, err
		}
		if re.Find(content) != nil {
			return true, 0, nil
		}
	}
	return false, 0, nil
}

func (s *Scanner) checkMP4Header(_ string, content []byte) (bool, float64, error) {
	if len(content) < 8 {
		return false, 0, nil
	}
	if string(content[4:8]) == "ftyp" {
		majorBrand := string(content[8:12])
		validBrands := []string{"isom", "mp42", "avc1", "m4v "}
		for _, brand := range validBrands {
			if majorBrand == brand {
				return false, 0, nil
			}
		}
		return true, 0, nil
	}
	return false, 0, nil
}
