# pat

Pat has a single dependancy : [typer](https://github.com/tiangolo/typer). Do `pip install typer` (or `pip install typer[all]` for nicely formatted errors)

Here are the currently supported commands. All commands can either be called on a single file, or a directory, in which case they will be applied to all files inside.

Do `pat COMMAND --help` for specifics regarding parameters, options, etc

## split

For splitting a spritesheet into individual files. You have options for specifying cell size or number of rows and columns, and more.

## rm-bg

For removing a single-color background.

## rm-shadow

For removing shadows. Here shadow means a pixel that only borders transparent or shadow pixels (not diagonally).
