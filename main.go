package main

import (
	"fmt"
	"io/fs"
	"io/ioutil"
	"musicplayer/player"
	"os"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

var allsongs []*song = make([]*song, 0, 1024)
var songlist []*song

var Repeat bool = true

func main() {

	path := "/mnt/127C43E17C43BE6B/OneDrive/Musik"

	//Create app, window and layout
	app := app.New()
	window := app.NewWindow("really bad MP3 player")
	contentRight := widget.NewList(

		//Get length of current song list
		func() int {
			return len(songlist)
		},

		//Function for creating a new song element
		func() fyne.CanvasObject {
			content := container.New(layout.NewHBoxLayout())
			content.Add(widget.NewButtonWithIcon("", theme.MediaPlayIcon(), nil))
			content.Add(widget.NewLabel(""))
			return content
		},

		//Function for updating song element
		func(i widget.ListItemID, o fyne.CanvasObject) {
			songlist[i].SetContent(o.(*fyne.Container))
		},
	)

	//Create sidemenu
	searchbar := widget.NewEntry()
	searchbar.SetPlaceHolder("Search..")
	searchbar.OnSubmitted = func(s string) {
		songlist = getFilesSearch(strings.ToLower(s))
	}
	searchButton := widget.NewButtonWithIcon("", theme.SearchIcon(), func() {
		searchbar.OnSubmitted(searchbar.Text)
	})
	sidemenu := container.NewVBox(
		container.NewBorder(
			nil, nil, nil, searchButton,
			searchbar,
		),
	)

	contentMain := container.NewHSplit(sidemenu, contentRight)

	//Get all songs
	songs, err := getFiles(path)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	//Add songs to allsongs array
	for _, f := range songs {
		s := NewSong(f.Name(), path+"/"+f.Name())
		allsongs = append(allsongs, s)
	}

	//Um
	songlist = allsongs

	window.SetContent(contentMain)
	window.Resize(fyne.NewSize(640, 480))
	window.ShowAndRun()
}

func NewSong(name string, path string) *song {
	s := song{
		name:       name,
		path:       path,
		nameSearch: strings.ToLower(name),
	}

	return &s
}

func (s *song) SetContent(content *fyne.Container) {

	//Set play button function
	content.Objects[0].(*widget.Button).OnTapped = func() {
		err := s.Play()
		if err != nil {
			fmt.Println(err.Error())
		}
	}

	//Set label name
	content.Objects[1].(*widget.Label).Text = s.name
	content.Refresh()

	//Return
	s.content = content
}

func (s *song) Play() error {

	go player.Run(s.path)

	//Song is playing'
	fmt.Printf("Playing song: %s\n", s.name)
	return nil
}

type song struct {
	name       string
	path       string
	nameSearch string
	content    *fyne.Container
}

//Get files from folder in alphabethical order
func getFiles(dir string) ([]fs.FileInfo, error) {

	//Try and get files
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	out := make([]fs.FileInfo, 0, len(files))
	for _, f := range files {
		if !f.IsDir() {
			out = append(out, f)
		}
	}

	//Return
	return out, nil
}

func getFilesSearch(s string) []*song {
	out := make([]*song, 0, len(allsongs))

	for _, f := range allsongs {
		if strings.Contains(f.nameSearch, s) {
			out = append(out, f)
		}
	}

	return out
}
