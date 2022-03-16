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

func (app *appData) debounceTimerFn() {
	app.pipeWriter()
	app.leadingEdgeFlag = false
	app.debounceTimer = nil
}

func (app *appData) pipeWriter() {
	if app.storeBuff.Len() == 0 {
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
		app.eof = true
		return true
	} else if n == 0 {
		return false
	}
	app.storeBuff.Write(app.readBuff[0:n])
	timerRunning := app.debounceTimer != nil
	// Stop old timer
	if timerRunning {
		app.debounceTimer.Stop()
	}
	app.debounceTimer = time.AfterFunc(time.Duration(app.args.DebounceTimeMs) * time.Millisecond, app.debounceTimerFn)
	// Dispatch leading edge event
	if app.args.LeadingEdge && ! app.leadingEdgeFlag {
		app.leadingEdgeFlag = true
		return true
	} else {
		return false
	}
}

func (app *appData) handlePipeData() {
	go func() {
		for ; ! app.eof ; {
			if app.pipeReader() {
				app.pipeWriter()
			}
		}
		app.quitCh <- struct{}{}
	}()
}
