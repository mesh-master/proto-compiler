package main

import (
	"bytes"
	"errors"
	"log"
	"os"
	"time"
)

const (
	DEBOUNCE_DEFAULT_WAIT_MS = 100
	READ_BUFFER_SIZE         = 1 << 16
)

var (
	ErrNoPipe = errors.New("command must be ran in a pipe")
)

type cliArgs struct {
	DebounceTimeMs int64  `short:"t" description:"Debounce time in milliseconds"`
	LeadingEdge    bool   `long:"leading-edge" description:""`
	ReplaceInput   string `long:"replace-input" description:"Replaces all input with a specified string"`
}

type appData struct {
	readBuff        []byte
	storeBuff       *bytes.Buffer
	args            cliArgs
	debounceTimer   *time.Timer
	leadingEdgeFlag bool
	eof             bool
	quitCh          chan struct{}
}

func NewAppData() *appData {
	data := new(appData)
	data.args.DebounceTimeMs = DEBOUNCE_DEFAULT_WAIT_MS
	data.args.LeadingEdge = false
	data.readBuff = make([]byte, READ_BUFFER_SIZE)
	data.storeBuff = &bytes.Buffer{}
	data.quitCh = make(chan struct{})
	return data
}

func main() {
	fi, err := os.Stdin.Stat()
	if err != nil {
		log.Fatal(err)
	}
	if fi.Mode()&os.ModeNamedPipe == 0 {
		log.Fatal(ErrNoPipe)
	}
	appData := NewAppData()
	appData.parseCliArgs()
	appData.initSigsHandler()
	appData.handlePipeData()
	<-appData.quitCh
}
