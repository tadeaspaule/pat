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

def _rgb_col_param(str_param: str, param_name: str, has_alpha: bool = False) -> list:
  col = [int(n) for n in str_param.split(",") if n.isnumeric()]
  if len(col) != (4 if has_alpha else 3) or max(col) > 255 or min(col) < 0:
    print(f"Invalid {param_name} format")
    exit(1)
  return tuple(col)


@app.command()
def split(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  output_dir: Annotated[str, typer.Option("--output-dir", "-od")] = "PATH_split",
  crop_to_content: Annotated[bool, typer.Option("--crop-to-content", "-c", help="default: False")] = False,
  crop_all: Annotated[int, typer.Option("--crop-all", "-ca", help="Crop new files by N from all sides")] = 0,
  crop_top: Annotated[int, typer.Option("--crop-top", "-ct", help="Crop new files by N from top")] = 0,
  crop_right: Annotated[int, typer.Option("--crop-right", "-cr", help="Crop new files by N from right")] = 0,
  crop_bottom: Annotated[int, typer.Option("--crop-bottom", "-cb", help="Crop new files by N from bottom")] = 0,
  crop_left: Annotated[int, typer.Option("--crop-left", "-cl", help="Crop new files by N from left")] = 0,
  single_row: Annotated[bool, typer.Option("--single-row", "-r", help="If true, assumes it is a single-row spritesheet with square cells")] = False,
  nx: Annotated[int, typer.Option("--nx", "-nx", help="Number of columns")] = None,
  ny: Annotated[int, typer.Option("--ny", "-ny", help="Number of rows")] = None,
  cell_x: Annotated[int, typer.Option("--cell-x", "-cx", help="Cell width")] = None,
  cell_y: Annotated[int, typer.Option("--cell-y", "-cy", help="Cell height")] = None,
  cell_size: Annotated[int, typer.Option("--cell-size", "-c", help="Square cell side")] = None,
  offset_x: Annotated[int, typer.Option("--offset-x", "-ox",help="Starting x offset")] = None,
  offset_y: Annotated[int, typer.Option("--offset-y", "-oy",help="Starting y offset")] = None,
  spacing_x: Annotated[int, typer.Option("--spacing-x", "-sx",help="Inner x margins of each cell")] = 0,
  spacing_y: Annotated[int, typer.Option("--spacing-y", "-sy",help="Inner y margins of each cell")] = 0,
  spacing: Annotated[int, typer.Option("--spacing", "-s",help="Inner x and y margins of each cell")] = 0,
  ):
  """
  Splits a spritesheet (or all spritesheets contained in a directory) into separate files.

  You have multiple ways of specifying cells, here is how they are prioritised:
  
  single_row > nx + ny > cell_size > cell_x + cell_y
  """
  if spacing != 0:
    spacing_x = spacing
    spacing_y = spacing
  if output_dir == "PATH_split":
    output_dir = None
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir,output_dir)
  if doing_dir and not single_row and cell_size is None and (cell_y is None or cell_x is None):
    print(f"When doing directory, need to specify either single_row or cell size")
    exit(1)
  elif not doing_dir and not single_row and cell_size is None and (cell_y is None or cell_x is None) and (nx is None or ny is None):
    print(f"When doing directory, need to specify one of: single_row, nx + ny, cell size")
    exit(1)
  if crop_all > 0:
    crop_right, crop_top, crop_bottom, crop_left = crop_all, crop_all, crop_all, crop_all
  crop_edges = [crop_top,crop_right,crop_bottom,crop_left]
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
      _split(fp, f"{output_dir}/{f}", crop_to_content, single_row, [nx,ny],[cell_x,cell_y],[offset_x, offset_y],[spacing_x,spacing_y], crop_edges)
  else:
    _split(path, output_dir, crop_to_content, single_row, [nx,ny],[cell_x,cell_y],[offset_x,offset_y],[spacing_x,spacing_y], crop_edges)

@app.command()
def rm_prefix(
  prefix: str,
  dir: str):
  if not os.path.exists(dir):
    print("Invalid path")
    exit(1)
  if not os.path.isdir(dir):
    print("Path is not a directory")
    exit(1)
  for fn in os.listdir(dir):
    if not fn.startswith(prefix):
      continue
    os.rename(f"{dir}/{fn}", f"{dir}/{fn[len(prefix):]}")

@app.command()
def rm_suffix(
  suffix: str,
  dir: str):
  if not os.path.exists(dir):
    print("Invalid path")
    exit(1)
  if not os.path.isdir(dir):
    print("Path is not a directory")
    exit(1)
  for fn in os.listdir(dir):
    parts = fn.split(".")
    b, ext = ".".join(parts[:-1]), parts[-1]
    if not b.endswith(suffix):
      continue
    os.rename(f"{dir}/{fn}", f"{dir}/{b[:-len(suffix)]}.{ext}")
 
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

@app.command()
def crop(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  crop_all: Annotated[int, typer.Option("--all", "-a", help="Crop file(s) by N from all sides")] = 0,
  crop_top: Annotated[int, typer.Option("--top", "-t", help="Crop file(s) by N from top")] = 0,
  crop_right: Annotated[int, typer.Option("--right", "-r", help="Crop file(s) by N from right")] = 0,
  crop_bottom: Annotated[int, typer.Option("--bottom", "-b", help="Crop file(s) by N from bottom")] = 0,
  crop_left: Annotated[int, typer.Option("--left", "-l", help="Crop file(s) by N from left")] = 0,
  ):
  """
  Crops edges from a file (or all files in directory)
  """
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir,None)
  output_path = dir + "_cropped" if doing_dir else _suffixed_path(file)
  if crop_all > 0:
    crop_right, crop_top, crop_bottom, crop_left = crop_all, crop_all, crop_all, crop_all
  c = [crop_top, crop_right, crop_bottom, crop_left]
  if doing_dir:
    if not os.path.exists(output_path):
      os.mkdir(output_path)
    for f in os.listdir(path):
      fp = f"{path}/{f}"
      if not os.path.isfile(fp):
        continue
      _crop(fp, f"{output_path}/{f}", c)
  else:
    _crop(path, output_path, c)

@app.command()
def pad(
  file: Annotated[str, typer.Option("--file", "-f")] = None,
  dir: Annotated[str, typer.Option("--dir", "-d")] = None,
  pad_all: Annotated[int, typer.Option("--all", "-a", help="Pad file(s) by N from all sides")] = 0,
  pad_top: Annotated[int, typer.Option("--top", "-t", help="Pad file(s) by N from top")] = 0,
  pad_right: Annotated[int, typer.Option("--right", "-r", help="Pad file(s) by N from right")] = 0,
  pad_bottom: Annotated[int, typer.Option("--bottom", "-b", help="Pad file(s) by N from bottom")] = 0,
  pad_left: Annotated[int, typer.Option("--left", "-l", help="Pad file(s) by N from left")] = 0,
  padding_color: Annotated[str, typer.Option("--color", "-c", help="Color for new edges, comma-separated RGBA")] = "0,0,0,0",
  ):
  """
  Pads a file (or all files in directory) with given color (default transparent)

  Output is named NAME_padded if -f, NAME_padded directory with same-name files if -d
  """
  path, doing_dir, doing_type, doing_type_opposite = _basic_file_dir_checks(file,dir,None)
  output_path = dir + "_padded" if doing_dir else _suffixed_path(file)
  if pad_all > 0:
    pad_right, pad_top, pad_bottom, pad_left = pad_all, pad_all, pad_all, pad_all
  p = [pad_top, pad_right, pad_bottom, pad_left]
  pc = _rgb_col_param(padding_color, "color", True)
  if doing_dir:
    if not os.path.exists(output_path):
      os.mkdir(output_path)
    for f in os.listdir(path):
      fp = f"{path}/{f}"
      if not os.path.isfile(fp):
        continue
      _pad(fp, f"{output_path}/{f}", p, pc)
  else:
    _pad(path, output_path, p, pc)

def _pad(path: str, output_path: str, padding: list[int], pad_color: list[int]):
  img = Image.open(path).convert("RGBA")
  width, height = img.size
  new_width = width + padding[1] + padding[3]
  new_height = height + padding[0] + padding[2]
  result = Image.new(img.mode, (new_width, new_height), pad_color)
  result.paste(img, (padding[3], padding[0]))
  result.save(output_path)

def _crop(path: str, output_path: str, c: list[int]):
  img = Image.open(path).convert("RGBA")
  img = img.crop((c[3],c[0],img.size[0]-c[1],img.size[1]-c[2]))
  img.save(output_path)
 
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

def _split(filename: str, output_dir: str, crop_content: bool, single_row: bool, n: list, cell_size: list, offset: list, spacing: list, crop_edges: list):
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
    nx = int(sheet.size[0] / dx)
    ny = int(sheet.size[1] / dy)
  elif nx > 0 and ny > 0:
    dx = int(sheet.size[0] / nx)
    dy = int(sheet.size[1] / ny)
  else:
    return
  spacex = spacing[0] if spacing[0] is not None else 0
  spacey = spacing[1] if spacing[1] is not None else 0

  for y in range(ny):
    for x in range(nx):
      sx = start[0] + x * dx
      sy = start[1] + y * dy
      icon = sheet.crop((
        sx+spacex+crop_edges[3],
        sy+spacey+crop_edges[0],
        sx+dx-spacex-crop_edges[1],
        sy+dy-spacey-crop_edges[2]))
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

