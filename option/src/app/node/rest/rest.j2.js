{% import "node.j2_macro" as m with context %}
const express = require('express')
const app = express()
const port = 8080
{{ m.import() }}

app.get('/info', (req, res) => {
    res.send("{{ deploy_name }} - {{ dbName }} - Node.JS - {{ ui_name  }} - Express")
})

app.get('/dept', async (req, res) => {
    {{ m.dept() }}
    res.send(rows)
})

app.listen(port, () => {
    console.log(`OCI Starter: listening on port ${port}`)
})

