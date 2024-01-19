package main
 
import (
    "fmt"
    "os"
    "net/http"
    "github.com/gin-gonic/gin"
    "encoding/json"
    "io/ioutil"
)

type Dept struct {
    Deptno string `json:"deptno"`
    Dname string `json:"dname"`
    Loc string `json:"loc"`
}

type Result struct {
	Hits struct {
		Hits []struct {
			Source struct {
				Deptno string `json:"deptno"`
				Dname  string `json:"dname"`
				Loc    string `json:"loc"`
			} `json:"_source"`
		} `json:"hits"`
	} `json:"hits"`
}

func dept(c *gin.Context) {
    response, err := http.Get("https://"+os.Getenv("DB_URL")+":9200/dept/_search?size=1000&scroll=1m&pretty=true")
    if err != nil {
        fmt.Print(err.Error())
        os.Exit(1)
    }
    jsonData, err := ioutil.ReadAll(response.Body)
    if err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
    fmt.Println(string(jsonData))

    body := Result{}
    err2 := json.Unmarshal([]byte(jsonData), &body)
    if err2 != nil {
        fmt.Println(err2)
        os.Exit(1)
    }
    fmt.Println(body)
    var results [] Dept;   
    for _, hit := range body.Hits.Hits {
        results = append(results, Dept{hit.Source.Deptno, hit.Source.Dname,hit.Source.Loc})
    }
    fmt.Println(results)
    c.IndentedJSON(http.StatusOK, results)
}

func info(c *gin.Context) {
    var s string =  "GoLang / OpenSearch"
    c.Data(http.StatusOK, "text/html", []byte(s))
}

func main() {
    router := gin.Default()
    router.GET("/info", info)
    router.GET("/dept", dept)
    router.Run(":8080")
}

