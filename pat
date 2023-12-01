#!/usr/bin/python3
from PIL import Image
import os
import typer
from typing_extensions import Annotated
from typing import Optional

app = typer.Typer()

def _basic_file_dir_checks(file: str, dir: str, output_dir: str):
  if file is None and dir is None:
    print("Need either file or directory specified")
    exit(1)
  path = dir if dir is not None else file
  doing_dir = dir is not None
  doing_type = 'directory' if doing_dir else 'file'
  doing_type_opposite = 'file' if doing_dir else 'directory'
  if not os.path.exists(path):
    print(f"Invalid {doing_type} path '{path}'")
    exit(1)
  if doing_dir != os.path.isdir(path):
    print(f"Doing {doing_type} but path is a {doing_type_opposite}")
    exit(1)
  if output_dir is not None and not os.path.isdir(output_dir):
    print("Invalid output_dir")
    exit(1)
  return (path, doing_dir, doing_type, doing_type_opposite)

def _suffixed_path(path: str, suffix: str) -> str:
  fparts = path.split(".")
  return f"{'.'.join(fparts[:-1])}{suffix}.{fparts[-1]}"

def _rgb_col_param(str_param: str, param_name: str) -> list:
  col = [int(n) for n in str_param.split(",") if n.isnumeric()]
  if len(col) != 3 or max(col) > 255 or min(col) < 0:
    print(f"Invalid {param_name} format")
    exit(1)
  return col

@app.command()
def split(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  output_dir: Annotated[str, typer.Option("--output-dir", "-od")] = "PATH_split",
  crop_to_content: Annotated[bool, typer.Option("--crop-to-content", "-c", help="default: False")] = False,
  single_row: Annotated[bool, typer.Option("--single-row", "-r", help="If true, assumes it is a single-row spritesheet with square cells")] = False,
  nx: Annotated[int, typer.Option("--nx", "-nx")] = None,
  ny: Annotated[int, typer.Option("--ny", "-ny")] = None,
  cell_x: Annotated[int, typer.Option("--cell-x", "-cx")] = None,
  cell_y: Annotated[int, typer.Option("--cell-y", "-cy")] = None,
  cell_size: Annotated[int, typer.Option("--cell-size", "-s", help="If set, assumes square cells of this size")] = None,
  offset_x: Annotated[int, typer.Option("--offset-x", "-ox")] = None,
  offset_y: Annotated[int, typer.Option("--offset-y", "-oy")] = None,
  spacing_x: Annotated[int, typer.Option("--spacing-x", "-sx")] = None,
  spacing_y: Annotated[int, typer.Option("--spacing-y", "-sy")] = None,
  ):
  """
  Splits a spritesheet (or all spritesheets contained in a directory) into separate files.

  You have multiple ways of specifying cells, here is how they are prioritised:
  
  single_row > nx + ny > cell_size > cell_x + cell_y
  """
  if output_dir == "PATH_split":
    output_dir = None
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir,output_dir)
  if doing_dir and not single_row and cell_size is None and (cell_y is None or cell_x is None):
    print(f"When doing directory, need to specify either single_row or cell size")
    exit(1)
  if cell_size is not None:
    cell_x = cell_size
    cell_y = cell_size
  if output_dir is None:
    output_dir = path + "_split"
  if not os.path.exists(output_dir):
    os.mkdir(output_dir)
  if doing_dir:
    for f in os.listdir(path):
      fp = f"{path}/{f}"
      if not os.path.isfile(fp):
        continue
      _split(fp, f"{output_dir}/{f}", crop_to_content, single_row, [nx,ny],[cell_x,cell_y],[offset_x],[offset_y],[spacing_x,spacing_y])
  else:
    _split(path, output_dir, crop_to_content, single_row, [nx,ny],[cell_x,cell_y],[offset_x,offset_y],[spacing_x,spacing_y])

  
@app.command()
def rm_bg(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  output_dir: Annotated[str, typer.Option("--output-dir", "-od", help="If not given, set to given path")] = None,
  filename_suffix: Annotated[str, typer.Option("--filename-suffix","-fs")] = "_rmbg",
  background_color: Annotated[str, typer.Option("--background-color", "-bg",help="Comma-separated list of 0-255 RGB values")] = "255,255,255"):
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir, output_dir)
  """
  Remvoes a single-color background from file (or all files contained in directory).
  
  By default, puts new files alongside old ones. If you want to replace them, use -fs ""
  """
  
  bg_col =  _rgb_col_param(background_color, "background_color")
  if doing_dir:
    for f in os.listdir(path):
      fp = f"{path}/{f}"
      if not os.path.isfile(fp):
        continue
      _remove_bg(fp, _suffixed_path(fp, filename_suffix) if output_dir is None else f"{output_dir}/{_suffixed_path(f,filename_suffix)}", bg_col)
  else:
    _remove_bg(path, _suffixed_path(path, filename_suffix) if output_dir is None else f"{output_dir}/{_suffixed_path(path.split('/')[-1],filename_suffix)}", bg_col)

@app.command()
def rm_shadow(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  output_dir: Annotated[str, typer.Option("--output-dir", "-od", help="If not given, set to given path")] = None,
  filename_suffix: Annotated[str, typer.Option("--filename-suffix","-fs")] = "_rms",
  shadow_color: Annotated[str, typer.Option("--shadow-color", "-cg",help="Comma-separated list of 0-255 RGB values")] = "0,0,0"):
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir, output_dir)
  """
  Remvoes shadow from file (or all files contained in directory). Here shadow means a pixel that only borders transparent or shadow pixels (not diagonally).
  
  By default, puts new files alongside old ones. If you want to replace them, use -fs ""
  """
  
  shadow_col =  _rgb_col_param(shadow_color, "shadow_color")
  if doing_dir:
    for f in os.listdir(path):
      fp = f"{path}/{f}"
      if not os.path.isfile(fp):
        continue
      _remove_shadow(fp, _suffixed_path(fp, filename_suffix) if output_dir is None else f"{output_dir}/{_suffixed_path(f,filename_suffix)}", shadow_col)
  else:
    _remove_shadow(path, _suffixed_path(path, filename_suffix) if output_dir is None else f"{output_dir}/{_suffixed_path(path.split('/')[-1],filename_suffix)}", shadow_col)

def _remove_shadow(path: str, new_path: str, shadow_col: list):
  img = Image.open(path).convert("RGBA")
  pixels = img.load()
  for x in range(img.size[0]): # for every pixel:
    for y in range(img.size[1]):
      non_shadow_adjacent, dirs = 0, [(-1,0),(0,-1),(1,0),(0,1)]
      for d in dirs:
        nx, ny = x + d[0], y + d[1]
        if nx >= 0 and ny >= 0 and nx < img.size[0] and ny < img.size[1]:
          if pixels[nx,ny][3] != 0 and pixels[nx,ny][:3] != shadow_col:
            non_shadow_adjacent += 1
      if non_shadow_adjacent == 0:
        pixels[x,y] = (0, 0, 0, 0)
  img.save(new_path)

def _remove_bg(path: str, new_path: str, bg_col: list):
  img = Image.open(path).convert("RGBA")
  pixels = img.load()
  bgcount = 0
  for x in range(img.size[0]): # for every pixel:
    for y in range(img.size[1]):
      is_bg = True
      for i in range(3):
        if pixels[x,y][i] != bg_col[i]:
          is_bg = False
          break
      if is_bg:
        bgcount += 1
        pixels[x,y] = (0,0,0,0)
  img.save(new_path)

def _split(filename: str, output_dir: str, crop_content: bool, single_row: bool, n: list, cell_size: list, offset: list, spacing: list):
  if not os.path.exists(output_dir) or not os.path.isdir(output_dir):
    os.mkdir(output_dir)
  sheet = Image.open(filename).convert("RGBA")
  count = 0
  # how many cells
  start = (0,0)
  if offset[0] is int:
    start[0] += offset[0]
  if offset[1] is int:
    start[1] += offset[1]
  dx = -1
  dy = -1
  nx = -1
  ny = -1
  if single_row:
    dy = sheet.size[1]
    dx = dy
  elif n[0] is not None and n[1] is not None:
    nx = n[0]
    ny = n[1]
  elif cell_size[0] is not None and cell_size[1] is not None:
    dx = cell_size[0]
    dy = cell_size[1]

  if dx > 0 and dy > 0:
    nx = sheet.size[0] / dx
    ny = sheet.size[1] / dy
  elif nx > 0 and ny > 0:
    dx = sheet.size[0] / nx
    dy = sheet.size[1] / ny
  else:
    return
  spacex = spacing[0] if spacing[0] is not None else 0
  spacey = spacing[1] if spacing[1] is not None else 0

  for y in range(ny):
    for x in range(nx):
      sx = start[0] + x * dx
      sy = start[1] + y * dy
      icon = sheet.crop((sx,sy,sx+dx-spacex,sy+dy-spacey))
      pix = icon.load()
      isempty = True
      minx,miny,maxx,maxy = icon.size[0],icon.size[1],0,0
      for xx in range(icon.size[0]):
        for yy in range(icon.size[1]):
          if pix[xx,yy][3] != 0:
            isempty = False
            minx = min(minx,xx)
            miny = min(miny,yy)
            maxx = max(maxx,xx)
            maxy = max(maxy,yy)
      if crop_content and not isempty:
        icon = icon.crop((minx,miny,maxx,maxy))
      if not isempty:
        icon.save(f"{output_dir}/{count}.png")
        count += 1

if __name__ == "__main__":
    app()
