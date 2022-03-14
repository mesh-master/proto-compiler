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
		if _, ok := <-sigs; ok {
			app.quitCh <- struct{}{}
		}
	}()
}
