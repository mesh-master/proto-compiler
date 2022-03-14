package main

import (
	"github.com/jessevdk/go-flags"
	"log"
)

func (app *appData) parseCliArgs() {
	parser := flags.NewParser(&app.args, flags.IgnoreUnknown)
	_, err := parser.Parse()
	if err != nil {
		log.Fatal(err)
	}
}
