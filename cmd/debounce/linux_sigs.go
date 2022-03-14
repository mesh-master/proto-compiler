package main

import (
	"os"
	"os/signal"
	"syscall"
)

func (app *appData) initSigsHandler() {
	go func() {
		sigs := make(chan os.Signal, 1)
		signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
		select {
		case <-sigs:
			app.quitCh <- struct{}{}
		}
	}()
}
