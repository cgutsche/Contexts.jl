using Documenter, Contexts

push!(LOAD_PATH,"../src/")
makedocs(sitename="Contexts.jl",
         authors="Christian Gutsche",
         pages = [
            "Home" => "index.md",
            "Contexts" => Any["Contexts.md", "ContextModeling.md", "PetriNets.md"],
            "Mixins" => "Mixins.md",
            "Teams" => "TeamsAndRoles.md",
            "Dynamic Teams" => "DynamicTeamsAndRoles.md"
            ]
        )
