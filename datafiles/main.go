// Copyright 2017 Hajime Hoshi
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build example
// +build example

package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/hajimehoshi/go-mp3"
)

func convert(fname string) error {
	f, err := os.Open(fname)
	if err != nil {
		return err
	}
	defer f.Close()

	d, err := mp3.NewDecoder(f)
	if err != nil {
		return err
	}

	//Open output file
	o, err := os.Create("out.raw")
	if err != nil {
		return err
	}

	//Write main file
	if _, err := io.Copy(o, d); err != nil {
		return err
	}
	o.Close()

	//Write file with samplerate
	o, err = os.Create("smplr")
	if err != nil {
		return err
	}

	//Write thing
	binary.Write(o, binary.LittleEndian, d.SampleRate())
	o.Close()

	//Return nil, because no errors happened :)
	return nil
}

func main() {

	//Get file name
	if len(os.Args) != 2 {
		close(errors.New(fmt.Sprintf("Expected 2 arguments, got %d.", len(os.Args))))
	}

	err := convert(os.Args[1])
	if err != nil {
		close(err)
	}
}

func close(err error) {
	f, _ := os.Create("error")
	f.WriteString(err.Error())
	f.Close()
	os.Exit(1)
}
