package main

import (
	"os"

	"github.com/hajimehoshi/go-mp3"
)

func main() {

	//Open test file
	rawfile, err := os.Open("test.mp3")
	if err != nil {
		panic(err.Error())
	}
	defer rawfile.Close()

	//Create encoder
	dec, err := mp3.NewDecoder(rawfile)
	if err != nil {
		panic(err.Error())
	}

	//Set up an output buffer
	out := make([]byte, dec.Length())

	//Repeat until I get bored
	for _, err := dec.Read(out); err == nil; {

	}

	os.WriteFile("out.raw", out, 0666)
}
