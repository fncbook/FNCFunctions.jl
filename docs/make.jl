using Documenter
using FNCFunctions

Documenter.Writers.HTMLWriter.HTML(sidebar_sitename=false)
makedocs(
    sitename = "FNC Functions",
    format = Documenter.HTML(),
    modules = [FNCFunctions],
    pages = [
        "index.md",
        "Functions" => "functions.md",
    ]
)

deploydocs(
    devbranch = "main",
    repo = "github.com/fncbook/FNCFunctions.jl.git",
)
