package main

import (
	"errors"
	"io"
	"log"
	"os"
	"time"
)

var (
	ErrStdoutWriteFailed = errors.New("failed to write to stdout")
)

func (app *appData) pipeWriter() {
	if app.storeBuff.Len() == 0 {
		app.quitCh <- struct{}{}
		return
	}
	_, err := os.Stdout.Write(app.storeBuff.Bytes())
	if err != nil {
		log.Fatal(ErrStdoutWriteFailed)
	}
	app.storeBuff.Reset()
}

// Returns true if stdin data have to be written to stdout
func (app *appData) pipeReader() bool {
	n, err := os.Stdin.Read(app.readBuff)
	if err == io.EOF {
		return true
	} else if n == 0 {
		return false
	}
	app.storeBuff.Write(app.readBuff[0:n])
	now := time.Now().UnixMilli()
	w := app.debounceWindow
	app.debounceWindow = now + app.args.DebounceTimeMs // Move the debounce window
	if now < w {
		return false
	} else {
		return true
	}
}

func (app *appData) handlePipeData() {
	go func() {
		for {
			if app.pipeReader() {
				app.pipeWriter()
			}
		}
	}()
}
