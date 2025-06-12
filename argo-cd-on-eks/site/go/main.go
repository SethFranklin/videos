package main

import (
	"log"
	"net/http"
	"os"
	"text/template"
)

type PageData struct {
	Environment string
	Path        string
}

var tmpl *template.Template
var err error
var pageData PageData

func main() {
	tmpl, err = template.ParseFiles("../html/index.html")
	if err != nil {
		panic(err)
	}
	pageData = PageData{Environment: os.Getenv("SITE_ENV"), Path: "/"}
	if pageData.Environment == "" {
		pageData.Environment = "SITE_ENV not set"
	}
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe("localhost:8080", nil))
}

func handler(w http.ResponseWriter, r *http.Request) {
	pageData.Path = r.URL.Path
	err = tmpl.Execute(w, pageData)
	if err != nil {
		panic(err)
	}
}
