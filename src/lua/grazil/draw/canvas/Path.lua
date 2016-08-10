-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License 



--- 
-- A Path models a path in the plane.
--
-- Following the PostScript/\textsc{pdf}/\textsc{svg} convention, a
-- path consists of a series of path segments, each of which can be
-- closed or not. Each path segement, in turn, consists of a series of
-- Bézier curvers and straight line segments; see
-- Section~\ref{section-paths} for an introduction to paths in
-- general.
--
-- A |Path| object is a table whose array part stores
-- |Coordinate| objects, |strings|, and |function|s that 
-- describe the path of the edge. The following strings are allowed in 
-- this array:
--
-- \begin{itemize}
-- \item |"moveto"| The line's path should stop at the current
-- position and then start anew at the next coordinate in the array.
-- \item |"lineto"| The line should continue from the current position
-- to the next coordinate in the array. 
-- \item |"curveto"| The line should continue form the current
-- position with a Bézier curve that is specified bz the next three
-- |Coordinate| objects (in the usual manner).
-- \item |"closepath"| The line's path should be ``closed'' in the sense
-- that the current subpath that was started with the most recent
-- moveto operation should now form a closed curve.
-- \end{itemize}
--
-- Instead of a |Coordinate|, a |Path| may also contain a function. In
-- this case, the function, when called, must return the |Coordinate|
-- that is ``meant'' by the position. This allows algorithms to
-- add coordinates to a path that are still not fixed at the moment
-- they are added to the path.

local Path = {}
Path.__index = Path



-- Imports

local Coordinate = require "grazil.draw.canvas.Coordinate"
local Bezier     = require "grazil.draw.canvas.Bezier"
local Transform  = require "grazil.draw.canvas.Transform"


-- Private function

function Path.rigid (x)
  if type(x) == "function" then
    return x()
  else
    return x
  end
end

local rigid = Path.rigid


---
-- Creates an empty path.
--
-- @param initial A table containing an array of strings and
-- coordinates that constitute the path. Coordinates may be given as
-- tables or as a pair of numbers. In this case, each pair of numbers
-- is converted into one coordinate. If omitted, a new empty path
-- is created.
--
-- @return A empty Path
--
function Path.new(initial)
  if initial then
    local new = {}
    local i = 1
    local count = 0
    while i <= #initial do
      local e = initial[i]
      if type(e) == "string" then
	assert (count == 0, "illformed path")
	if e == "moveto" then
	  count = 1
	elseif e == "lineto" then
	  count = 1
	elseif e == "closepath" then
	  count = 0
	elseif e == "curveto" then
	  count = 3
	else
	  error ("unknown path command " .. e)
	end
	new[#new+1] = e
      elseif type(e) == "number" then
	if count == 0 then
	  new[#new+1] = "lineto"
	else
	  count = count - 1
	end
	new[#new+1] = Coordinate.new(e,initial[i+1])
	i = i + 1
      elseif type(e) == "table" or type(e) == "function" then
	if count == 0 then
	  new[#new+1] = "lineto"
	else
	  count = count - 1
	end
	new[#new+1] = e
      else
	error ("invalid object on path")
      end
      i = i + 1
    end
    return setmetatable(new, Path)
  else
    return setmetatable({}, Path)
  end
end


---
-- Creates a copy of a path.
--
-- @return A copy of the path

function Path:clone()
  local new = {}
  for _,x in ipairs(self) do
    if type(x) == "table" then
      new[#new+1] = x:clone()
    else
      new[#new+1] = x
    end
  end
  return setmetatable(new, Path)
end



---
-- Returns the path in reverse order.
--
-- @return A copy of the reversed path

function Path:reversed()
  
  -- First, build segments
  local subpaths = {}
  local subpath  = {}

  local function closepath ()
    if subpath.start then
      subpaths [#subpaths + 1] = subpath
      subpath = {}
    end
  end
  
  local prev
  local start

  local i = 1
  while i <= #self do
    local x = self[i]
    if x == "lineto" then
      subpath[#subpath+1] = {
	action   = 'lineto',
	from     = prev,
	to       = self[i+1]
      }
      prev = self[i+1]
      i = i + 2
    elseif x == "moveto" then
      closepath()
      prev = self[i+1]
      start = prev
      subpath.start = prev
      i = i + 2
    elseif x == "closepath" then
      subpath [#subpath + 1] = {
	action   = "closepath",
	from     = prev,
	to       = start,
      }
      prev = nil
      start = nil
      closepath()
      i = i + 1
    elseif x == "curveto" then
      local s1, s2, to = self[i+1], self[i+2], self[i+3]
      subpath [#subpath + 1] = {
	action    = "curveto",
	from      = prev,
	to        = to,
	support_1 = s1,
	support_2 = s2,
      }
      prev = self[i+3]
      i = i + 4
    else
      error ("illegal path command '" .. x .. "'")
    end
  end
  closepath ()
  
  local new = Path.new ()

  for _,subpath in ipairs(subpaths) do
    if #subpath == 0 then
      -- A subpath that consists only of a moveto:
      new:appendMoveto(subpath.start)
    else
      -- We start with a moveto to the end point:
      new:appendMoveto(subpath[#subpath].to)
      
      -- Now walk backwards:
      for i=#subpath,1,-1 do
	if subpath[i].action == "lineto" then
	  new:appendLineto(subpath[i].from)
	elseif subpath[i].action == "closepath" then
	  new:appendLineto(subpath[i].from)
	elseif subpath[i].action == "curveto" then
	  new:appendCurveto(subpath[i].support_2,
			    subpath[i].support_1,
			    subpath[i].from)
	else
	  error("illegal path command")
	end
      end

      -- Append a closepath, if necessary
      if subpath[#subpath].action == "closepath" then
	new:appendClosepath()
      end
    end
  end
  
  return new
end


---
-- Transform all points on a path.
--
-- @param t A transformation, see |pgf.gd.lib.Transform|. It is
-- applied to all |Coordinate| objects on the path.

function Path:transform(t)
  for _,c in ipairs(self) do
    if type(c) == "table" then
      c:apply(t)
    end
  end
end


---
-- Shift all points on a path.
--
-- @param x An $x$-shift
-- @param y A $y$-shift

function Path:shift(x,y)
  for _,c in ipairs(self) do
    if type(c) == "table" then
      c.x = c.x + x
      c.y = c.y + y
    end
  end
end


---
-- Shift by all points on a path.
--
-- @param x A coordinate

function Path:shiftByCoordinate(x)
  for _,c in ipairs(self) do
    if type(c) == "table" then
      c.x = c.x + x.x
      c.y = c.y + x.y
    end
  end
end


---
-- Makes the path empty.
--

function Path:clear()
  for i=1,#self do
    self[i] = nil
  end
end


---
-- Appends a |moveto| to the path.
--
-- @param x A |Coordinate| or |function| or, if the |y| parameter is
-- not |nil|, a number that is the $x$-part of a coordiante .
-- @param y The $y$-part of the coordinate.

function Path:appendMoveto(x,y)
  self[#self + 1] = "moveto"
  self[#self + 1] = y and Coordinate.new(x,y) or x
end


---
-- Appends a |lineto| to the path.
--
-- @param x A |Coordinate| or |function|, if the |y| parameter is not
-- |nil|, a number that is the $x$-part of a coordiante .
-- @param y The $y$-part of the coordinate.

function Path:appendLineto(x,y)
  self[#self + 1] = "lineto"
  self[#self + 1] = y and Coordinate.new(x,y) or x
end



---
-- Appends a |closepath| to the path.

function Path:appendClosepath()
  self[#self + 1] = "closepath"
end


---
-- Appends a |curveto| to the path. There can be either three
-- coordinates (or functions) as parameters (the two support points
-- and the target) or six numbers, where two consecutive numbers form a
-- |Coordinate|. Which case is meant is detected by the presence of a
-- sixth non-nil parameter.

function Path:appendCurveto(a,b,c,d,e,f)
  self[#self + 1] = "curveto"
  if f then
    self[#self + 1] = Coordinate.new(a,b)
    self[#self + 1] = Coordinate.new(c,d)
    self[#self + 1] = Coordinate.new(e,f)
  else
    self[#self + 1] = a
    self[#self + 1] = b
    self[#self + 1] = c
  end    
end






---
-- Makes a path ``rigid,'' meaning that all coordinates that are only
-- given as functions are replaced by the values these functions
-- yield.

function Path:makeRigid()
  for i=1,#self do
    self[i] = rigid(self[i])
  end
end


---
-- Returns an array of all coordinates that are present in a
-- path. This means, essentially, that all strings are filtered out.
--
-- @return An array of all coordinate objects on the path.

function Path:coordinates()
  local cloud = {}
  for i=1,#self do
    local p = self[i]
    if type(p) == "table" then
      cloud[#cloud + 1] = p
    elseif type(p) == "function" then
      cloud[#cloud + 1] = p()
    end
  end
  return cloud
end


---
-- Returns a bounding box of the path. This will not necessarily be
-- the minimal bounding box in case the path contains curves because,
-- then, the support points of the curve are used for the computation
-- rather than the actual boinding box of the path.
--
-- If the path contains no coordinates, all return values are 0.
--
-- @return |min_x| The minimum $x$ value of the bounding box of the path
-- @return |min_y| The minimum $y$ value
-- @return |max_x|
-- @return |max_y|
-- @return |center_x| The center of the bounding box
-- @return |center_y| 

function Path:boundingBox()
  if #self > 0 then
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    
    for i=1,#self do
      local c = rigid(self[i])
      if type(c) == "table" then
	local x = c.x
	local y = c.y
	if x < min_x then min_x = x end
	if y < min_y then min_y = y end
	if x > max_x then max_x = x end
	if y > max_y then max_y = y end
      end
    end

    if min_x ~= math.huge then
      return min_x, min_y, max_x, max_y, (min_x+max_x) / 2, (min_y+max_y) / 2
    end
  end
  return 0, 0, 0, 0, 0, 0
end


-- Forwards

local segmentize, bb, boxes_intersect, intersect_curves

local eps = 0.0001



---
-- Computes all intersections of a path with another path and returns
-- them as an array of coordinates. The intersections will be sorted
-- ``along the path |self|.'' The implementation uses a
-- divide-and-conquer approach that should be reasonably fast in
-- practice. 
--
-- @param path Another path
--
-- @return Array of all intersections of |path| with |self| in the
-- order they appear on |self|. Each entry of this array is a table
-- with the following fields:
-- \begin{itemize}
-- \item |index| The index of the segment in |self| where
-- the intersection occurs.
-- \item |time| The ``time'' at which a point travelling along the
-- segment from its start point to its end point.
-- \item |point| The point itself.
-- \end{itemize}

function Path:intersectionsWith(path)

  local p1    = segmentize(self)
  local memo1 = prepare_memo(p1)
  local p2    = segmentize(path)
  local memo2 = prepare_memo(p2)

  local intersections = {}
  
  local function intersect_segments(i1, i2)
    
    local s1 = p1[i1]
    local s2 = p2[i2]
    local r = {}
    
    if s1.action == 'lineto' and s2.action == 'lineto' then
      local a = s2.to.x - s2.from.x
      local b = s1.from.x - s1.to.x
      local c = s2.from.x - s1.from.x
      local d = s2.to.y - s2.from.y
      local e = s1.from.y - s1.to.y
      local f = s2.from.y - s1.from.y
      
      local det = a*e - b*d
      
      if math.abs(det) > eps*eps then
	local t, s = (c*d - a*f)/det, (b*f - e*c)/det

	if t >= 0 and t<=1 and s>=0 and s <= 1 then
	  local p = s1.from:clone()
	  p:moveTowards(s1.to, t)
	  return { { time = t, point = p } }
	end
      end
    elseif s1.action == 'lineto' and s2.action == 'curveto' then
      intersect_curves (0, 1,
			s1.from.x, s1.from.y,
			s1.from.x*2/3+s1.to.x*1/3, s1.from.y*2/3+s1.to.y*1/3,
			s1.from.x*1/3+s1.to.x*2/3, s1.from.y*1/3+s1.to.y*2/3,
			s1.to.x, s1.to.y,
			s2.from.x, s2.from.y,
			s2.support_1.x, s2.support_1.y,
			s2.support_2.x, s2.support_2.y,
			s2.to.x, s2.to.y,
			r)
    elseif s1.action == 'curveto' and s2.action == 'lineto' then
      intersect_curves (0, 1,
			s1.from.x, s1.from.y,
			s1.support_1.x, s1.support_1.y,
			s1.support_2.x, s1.support_2.y,
			s1.to.x, s1.to.y,
			s2.from.x, s2.from.y,
			s2.from.x*2/3+s2.to.x*1/3, s2.from.y*2/3+s2.to.y*1/3,
			s2.from.x*1/3+s2.to.x*2/3, s2.from.y*1/3+s2.to.y*2/3,
			s2.to.x, s2.to.y,
			r)
    else
      intersect_curves (0, 1,
			s1.from.x, s1.from.y,
			s1.support_1.x, s1.support_1.y,
			s1.support_2.x, s1.support_2.y,
			s1.to.x, s1.to.y,
			s2.from.x, s2.from.y,
			s2.support_1.x, s2.support_1.y,
			s2.support_2.x, s2.support_2.y,
			s2.to.x, s2.to.y,
			r)
    end
    return r
  end
  
  local function intersect (i1, j1, i2, j2)

    if i1 > j1 or i2 > j2 then
      return
    end
    
    local bb1 = bb(i1, j1, memo1)
    local bb2 = bb(i2, j2, memo2)
    
    if boxes_intersect(bb1, bb2) then
      -- Ok, need to do something
      if i1 == j1 and i2 == j2 then
	local intersects = intersect_segments (i1, i2)
	for _,t in ipairs(intersects) do
	  intersections[#intersections+1] = {
	    time = t.time,
	    index = p1[i1].path_pos,
	    point = t.point
	  }
	end
      elseif i1 == j1 then
	local m2 = math.floor((i2 + j2) / 2)
	intersect(i1, j1, i2, m2)
	intersect(i1, j1, m2+1, j2)
      elseif i2 == j2 then
	local m1 = math.floor((i1 + j1) / 2)
	intersect(i1, m1, i2, j2)
	intersect(m1+1, j1, i2, j2)
      else
	local m1 = math.floor((i1 + j1) / 2)
	local m2 = math.floor((i2 + j2) / 2)
	intersect(i1, m1, i2, m2)
	intersect(m1+1, j1, i2, m2)
	intersect(i1, m1, m2+1, j2)
	intersect(m1+1, j1, m2+1, j2)
      end
    end    
  end
  
  -- Run the recursion
  intersect(1, #p1, 1, #p2)

  -- Sort
  table.sort(intersections, function(a,b)
			      return a.index < b.index or
				a.index == b.index and a.time < b.time
			    end)
  
  -- Remove duplicates
  local remains = {}
  remains[1] = intersections[1]
  for i=2,#intersections do
    local next = intersections[i]
    local prev = remains[#remains]
    if math.abs(next.point.x - prev.point.x) + math.abs(next.point.y - prev.point.y) > eps then
      remains[#remains+1] = next
    end
  end

  return remains
end


-- Returns true if two bounding boxes intersection

function boxes_intersect (bb1, bb2)
  return (bb1.max_x >= bb2.min_x - eps*eps and
	  bb1.min_x <= bb2.max_x + eps*eps and
	  bb1.max_y >= bb2.min_y - eps*eps and
	  bb1.min_y <= bb2.max_y + eps*eps)
end


-- Turns a path into a sequence of segments, each being either a
-- lineto or a curveto from some point to another point. It also sets
-- up a memoization array for the bounding boxes.

function segmentize (path)

  local prev
  local start
  local s = {}

  local i = 1
  while i <= #path do
    local x = path[i]
    
    if x == "lineto" then
      x = rigid(path[i+1])
      s [#s + 1] = {
	path_pos = i,
	action   = "lineto",
	from     = prev,
	to       = x,
	bb       = {
	  min_x = math.min(prev.x, x.x),
	  max_x = math.max(prev.x, x.x),
	  min_y = math.min(prev.y, x.y),
	  max_y = math.max(prev.y, x.y),
	}
      }
      prev = x
      i = i + 2
    elseif x == "moveto" then
      prev = rigid(path[i+1])
      start = prev
      i = i + 2
    elseif x == "closepath" then
      s [#s + 1] = {
	path_pos = i,
	action   = "lineto",
	from     = prev,
	to       = start,
	bb       = {
	  min_x = math.min(prev.x, start.x),
	  max_x = math.max(prev.x, start.x),
	  min_y = math.min(prev.y, start.y),
	  max_y = math.max(prev.y, start.y),
	}
      }
      prev = nil
      start = nil
      i = i + 1
    elseif x == "curveto" then
      local s1, s2, to = rigid(path[i+1]), rigid(path[i+2]), rigid(path[i+3])
      s [#s + 1] = {
	action    = "curveto",
	path_pos  = i,
	from      = prev,
	to        = to,
	support_1 = s1,
	support_2 = s2,
	bb        = {
	  min_x = math.min(prev.x, s1.x, s2.x, to.x),
	  max_x = math.max(prev.x, s1.x, s2.x, to.x),
	  min_y = math.min(prev.y, s1.y, s2.y, to.y),
	  max_y = math.max(prev.y, s1.y, s2.y, to.y),
	}
      }
      prev = path[i+3]
      i = i + 4
    else
      error ("illegal path command '" .. x .. "'")
    end
  end

  return s
end


function prepare_memo (s)
  
  local memo = {}
  
  memo.base = #s
  
  -- Fill memo table
  for i,e in ipairs (s) do
    memo[i*#s + i] = e.bb
  end
  
  return memo
end


-- This function computes the bounding box of all segments between i
-- and j (inclusively)

function bb (i, j, memo)
  local b = memo[memo.base*i + j]
  if not b then
    assert (i < j, "memoization table filled incorrectly")
    
    local mid = math.floor((i+j)/2)
    local bb1 = bb (i, mid, memo)
    local bb2 = bb (mid+1, j, memo)
    b = {
      min_x = math.min(bb1.min_x, bb2.min_x),
      max_x = math.max(bb1.max_x, bb2.max_x),
      min_y = math.min(bb1.min_y, bb2.min_y),
      max_y = math.max(bb1.max_y, bb2.max_y)
    }
    memo[memo.base*i + j] = b
  end
  
  return b
end



-- Intersect two Bezier curves. 

function intersect_curves(t0, t1,
			  c1_ax, c1_ay, c1_bx, c1_by,
			  c1_cx, c1_cy, c1_dx, c1_dy,
			  c2_ax, c2_ay, c2_bx, c2_by,
			  c2_cx, c2_cy, c2_dx, c2_dy,
			  intersections)
  
  -- Only do something, if the bounding boxes intersect:
  local c1_min_x = math.min(c1_ax, c1_bx, c1_cx, c1_dx)
  local c1_max_x = math.max(c1_ax, c1_bx, c1_cx, c1_dx)
  local c1_min_y = math.min(c1_ay, c1_by, c1_cy, c1_dy)
  local c1_max_y = math.max(c1_ay, c1_by, c1_cy, c1_dy)
  local c2_min_x = math.min(c2_ax, c2_bx, c2_cx, c2_dx)
  local c2_max_x = math.max(c2_ax, c2_bx, c2_cx, c2_dx)
  local c2_min_y = math.min(c2_ay, c2_by, c2_cy, c2_dy)
  local c2_max_y = math.max(c2_ay, c2_by, c2_cy, c2_dy)
    
  if c1_max_x >= c2_min_x and
     c1_min_x <= c2_max_x and
     c1_max_y >= c2_min_y and
     c1_min_y <= c2_max_y then     
     
    -- Everything "near together"?
    if c1_max_x - c1_min_x < eps and c1_max_y - c1_min_y < eps then

      -- Compute intersection of lines c1_a to c1_d and c2_a to c2_d
      local a = c2_dx - c2_ax
      local b = c1_ax - c1_dx
      local c = c2_ax - c1_ax
      local d = c2_dy - c2_ay
      local e = c1_ay - c1_dy
      local f = c2_ay - c1_ay
      
      local det = a*e - b*d
      local t
      
      t = (c*d - a*f)/det
      if t<0 then
	t=0
      elseif t>1 then
	t=1
      end

      intersections [#intersections + 1] = {
	time = t0 + t*(t1-t0),
	point = Coordinate.new(c1_ax + t*(c1_dx-c1_ax), c1_ay+t*(c1_dy-c1_ay))
      }
    else
      -- Cut 'em in half!
      local c1_ex, c1_ey = (c1_ax + c1_bx)/2, (c1_ay + c1_by)/2
      local c1_fx, c1_fy = (c1_bx + c1_cx)/2, (c1_by + c1_cy)/2
      local c1_gx, c1_gy = (c1_cx + c1_dx)/2, (c1_cy + c1_dy)/2
      
      local c1_hx, c1_hy = (c1_ex + c1_fx)/2, (c1_ey + c1_fy)/2
      local c1_ix, c1_iy = (c1_fx + c1_gx)/2, (c1_fy + c1_gy)/2
            
      local c1_jx, c1_jy = (c1_hx + c1_ix)/2, (c1_hy + c1_iy)/2
      
      local c2_ex, c2_ey = (c2_ax + c2_bx)/2, (c2_ay + c2_by)/2
      local c2_fx, c2_fy = (c2_bx + c2_cx)/2, (c2_by + c2_cy)/2
      local c2_gx, c2_gy = (c2_cx + c2_dx)/2, (c2_cy + c2_dy)/2
      
      local c2_hx, c2_hy = (c2_ex + c2_fx)/2, (c2_ey + c2_fy)/2
      local c2_ix, c2_iy = (c2_fx + c2_gx)/2, (c2_fy + c2_gy)/2
            
      local c2_jx, c2_jy = (c2_hx + c2_ix)/2, (c2_hy + c2_iy)/2

      intersect_curves (t0, (t0+t1)/2,
			c1_ax, c1_ay, c1_ex, c1_ey, c1_hx, c1_hy, c1_jx, c1_jy,
			c2_ax, c2_ay, c2_ex, c2_ey, c2_hx, c2_hy, c2_jx, c2_jy,
			intersections)
      intersect_curves (t0, (t0+t1)/2,
			c1_ax, c1_ay, c1_ex, c1_ey, c1_hx, c1_hy, c1_jx, c1_jy,
			c2_jx, c2_jy, c2_ix, c2_iy, c2_gx, c2_gy, c2_dx, c2_dy,
			intersections)
      intersect_curves ((t0+t1)/2, t1,
			c1_jx, c1_jy, c1_ix, c1_iy, c1_gx, c1_gy, c1_dx, c1_dy,
			c2_ax, c2_ay, c2_ex, c2_ey, c2_hx, c2_hy, c2_jx, c2_jy,
			intersections)
      intersect_curves ((t0+t1)/2, t1,
			c1_jx, c1_jy, c1_ix, c1_iy, c1_gx, c1_gy, c1_dx, c1_dy,
			c2_jx, c2_jy, c2_ix, c2_iy, c2_gx, c2_gy, c2_dx, c2_dy,
			intersections)      
    end
  end
end


---
-- Shorten a path at the beginning. We are given the index of a
-- segment inside the path as well as a point in time along this
-- segment. The path is now shortened so that everything before this
-- segment and everything in the segment before the given time is
-- removed from the path.
--
-- @param index The index of a path segment. 
-- @param time A time along the specified path segment.

function Path:cutAtBeginning(index, time)
  
  local cut_path = Path:new ()
  
  -- Ok, first, we need to find the segment *before* the current
  -- one. Usually, this will be a moveto or a lineto, but things could
  -- be different.
  assert (type(self[index-1]) == "table" or type(self[index-1]) == "function",
	  "segment before intersection does not end with a coordinate")

  local from   = rigid(self[index-1])
  local action = self[index]
  
  -- Now, depending on the type of segment, we do different things:
  if action == "lineto" then
    
    -- Ok, compute point:
    local to = rigid(self[index+1])

    from:moveTowards(to, time)
    
    -- Ok, this is easy: We start with a fresh moveto ...
    cut_path[1] = "moveto"
    cut_path[2] = from

    -- ... and copy the rest
    for i=index,#self do
      cut_path[#cut_path+1] = self[i]
    end
  elseif action == "curveto" then

    local to = rigid(self[index+3])
    local s1 = rigid(self[index+1])
    local s2 = rigid(self[index+2])

    -- Now, compute the support vectors and the point at time:
    from:moveTowards(s1, time)
    s1:moveTowards(s2, time)
    s2:moveTowards(to, time)

    from:moveTowards(s1, time)
    s1:moveTowards(s2, time)

    from:moveTowards(s1, time)

    -- Ok, this is easy: We start with a fresh moveto ...
    cut_path[1] = "moveto"
    cut_path[2] = from
    cut_path[3] = "curveto"
    cut_path[4] = s1
    cut_path[5] = s2
    cut_path[6] = to

    -- ... and copy the rest
    for i=index+4,#self do
      cut_path[#cut_path+1] = self[i]
    end
    
  elseif action == "closepath" then
    -- Let us find the start point:
    local found 
    for i=index,1,-1 do
      if self[i] == "moveto" then
	-- Bingo:
	found = i
	break
      end
    end

    assert(found, "no moveto found in path")
    
    local to = rigid(self[found+1])
    from:moveTowards(to,time)

    cut_path[1] = "moveto"
    cut_path[2] = from
    cut_path[3] = "lineto"
    cut_path[4] = to

    -- ... and copy the rest
    for i=index+1,#self do
      cut_path[#cut_path+1] = self[i]
    end
  else
    error ("wrong path operation")
  end

  -- Move cut_path back:
  for i=1,#cut_path do
    self[i] = cut_path[i]
  end
  for i=#cut_path+1,#self do
    self[i] = nil
  end
end




---
-- Shorten a path at the end. This method works like |cutAtBeginning|,
-- only the path is cut at the end.
--
-- @param index The index of a path segment. 
-- @param time A time along the specified path segment.

function Path:cutAtEnd(index, time)

  local cut_path = Path:new ()
  
  -- Ok, first, we need to find the segment *before* the current
  -- one. Usually, this will be a moveto or a lineto, but things could
  -- be different.
  assert (type(self[index-1]) == "table" or type(self[index-1]) == "function",
	  "segment before intersection does not end with a coordinate")

  local from   = rigid(self[index-1])
  local action = self[index]
  
  -- Now, depending on the type of segment, we do different things:
  if action == "lineto" then
    
    -- Ok, compute point:
    local to = rigid(self[index+1])
    to:moveTowards(from, 1-time)
    
    for i=1,index do
      cut_path[i] = self[i]
    end
    cut_path[index+1] = to
    
  elseif action == "curveto" then
    
    local s1 = rigid(self[index+1])
    local s2 = rigid(self[index+2])
    local to = rigid(self[index+3])

    -- Now, compute the support vectors and the point at time:
    to:moveTowards(s2, 1-time)
    s2:moveTowards(s1, 1-time)
    s1:moveTowards(from, 1-time)

    to:moveTowards(s2, 1-time)
    s2:moveTowards(s1, 1-time)

    to:moveTowards(s2, 1-time)

    -- ... and copy the rest
    for i=1,index do
      cut_path[i] = self[i]
    end

    cut_path[index+1] = s1
    cut_path[index+2] = s2
    cut_path[index+3] = to
    
  elseif action == "closepath" then
    -- Let us find the start point:
    local found 
    for i=index,1,-1 do
      if self[i] == "moveto" then
	-- Bingo:
	found = i
	break
      end
    end

    assert(found, "no moveto found in path")
    
    local to = rigid(self[found+1]:clone())
    to:moveTowards(from,1-time)

    for i=1,index-1 do
      cut_path[i] = self[i]
    end
    cut_path[index] = 'lineto'
    cut_path[index+1] = to
  else
    error ("wrong path operation")
  end

  -- Move cut_path back:
  for i=1,#cut_path do
    self[i] = cut_path[i]
  end
  for i=#cut_path+1,#self do
    self[i] = nil
  end
end




---
-- ``Pads'' the path. The idea is the following: Suppose we stroke the
-- path with a pen whose width is twice the value |padding|. The outer
-- edge of this stroked drawing is now a path by itself. The path will
-- be a bit longer and ``larger.'' The present function tries to
-- compute an approximation to this resulting path.
--
-- The algorithm used to compute the enlarged part does not necessarily
-- compute the precise new path. It should work correctly for polyline
-- paths, but not for curved paths.
--
-- @param padding A padding distance.
-- @return The padded path.
--

function Path:pad(padding)
  
  local padded = self:clone()
  padded:makeRigid()

  if padding == 0 then
    return padded
  end
  
  -- First, decompose the path into subpaths:
  local subpaths = {}
  local subpath = {}
  local start_index = 1
  
  local function closepath(end_index)
    if #subpath >= 1 then
      subpath.start_index = start_index
      subpath.end_index   = end_index
      start_index = end_index + 1
      
      local start = 1
      if (subpath[#subpath] - subpath[1]):norm() < 0.01 and subpath[2] then
	start = 2
	subpath.skipped = subpath[1]
      end
      subpath[#subpath + 1] = subpath[start]
      subpath[#subpath + 1] = subpath[start+1]
      subpaths[#subpaths + 1] = subpath
      subpath = {}
    end
  end
  
  for i,p in ipairs(padded) do
    if p ~= "closepath" then
      if type(p) == "table" then
	subpath[#subpath + 1] = p
      end
    else
      closepath (i)
    end
  end
  closepath(#padded)

  -- Second, iterate over the subpaths:
  for _,subpath in ipairs(subpaths) do
    local new_coordinates = {}
    local _,_,_,_,c_x,c_y = Coordinate.boundingBox(subpath)
    local c = Coordinate.new(c_x,c_y)
    
    -- Find out the orientation of the path
    local count = 0
    for i=1,#subpath-2 do
      local d2 = subpath[i+1] - subpath[i]
      local d1 = subpath[i+2] - subpath[i+1]

      local diff = math.atan2(d2.y,d2.x) - math.atan2(d1.y,d1.x)
      
      if diff < -math.pi then
	count = count + 1
      elseif diff > math.pi then
	count = count - 1
      end
    end
    
    for i=2,#subpath-1 do
      local p = subpath[i]
      local d1 = subpath[i] - subpath[i-1]
      local d2 = subpath[i+1] - subpath[i]
      
      local orth1 = Coordinate.new(-d1.y, d1.x)
      local orth2 = Coordinate.new(-d2.y, d2.x)

      orth1:normalize()
      orth2:normalize()

      if count < 0 then
	orth1:scale(-1)
	orth2:scale(-1)
      end

      -- Ok, now we want to compute the intersection of the lines
      -- perpendicular to p + padding*orth1 and p + padding*orth2:
      
      local det = orth1.x * orth2.y - orth1.y * orth2.x

      local c
      if math.abs(det) < 0.1 then
	c = orth1 + orth2
	c:scale(padding/2)
      else
	c = Coordinate.new (padding*(orth2.y-orth1.y)/det, padding*(orth1.x-orth2.x)/det)
      end

      new_coordinates[i] = c+p
    end

    for i=2,#subpath-1 do
      local p = subpath[i]
      local new_p = new_coordinates[i]
      p.x = new_p.x
      p.y = new_p.y
    end

    if subpath.skipped then
      local p = subpath[1]
      local new_p = new_coordinates[#subpath-2]
      p.x = new_p.x
      p.y = new_p.y      
    end
  
    -- Now, we need to correct the curveto fields:
    for i=subpath.start_index,subpath.end_index do
      if self[i] == 'curveto' then
	local from = rigid(self[i-1])
	local s1   = rigid(self[i+1])
	local s2   = rigid(self[i+2])
	local to   = rigid(self[i+3])
	
	local p1x, p1y, _, _, h1x, h1y =
	  Bezier.atTime(from.x, from.y, s1.x, s1.y, s2.x, s2.y,
			to.x, to.y, 1/3)
	
	local p2x, p2y, _, _, _, _, h2x, h2y =
	  Bezier.atTime(from.x, from.y, s1.x, s1.y, s2.x, s2.y,
			to.x, to.y, 2/3)
	
	local orth1 = Coordinate.new (p1y - h1y, -(p1x - h1x))
	orth1:normalize()
	orth1:scale(-padding)
	
	local orth2 = Coordinate.new (p2y - h2y, -(p2x - h2x))
	orth2:normalize()
	orth2:scale(padding)

	if count < 0 then
	  orth1:scale(-1)
	  orth2:scale(-1)
	end
	
	local new_s1, new_s2 =
	  Bezier.supportsForPointsAtTime(padded[i-1],
					 Coordinate.new(p1x+orth1.x,p1y+orth1.y), 1/3,
					 Coordinate.new(p2x+orth2.x,p2y+orth2.y), 2/3,
					 padded[i+3])
	
	padded[i+1] = new_s1
	padded[i+2] = new_s2
      end
    end
  end
  
  return padded
end



local rigid = Path.rigid

local tan = math.tan
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local atan2 = math.atan2
local abs = math.abs

local to_rad = math.pi/180
local to_deg = 180/math.pi
local pi_half = math.pi/2

local function sin_quarter(x)
  x = x % 360
  if x == 0 then
    return 0
  elseif x == 90 then
    return 1
  elseif x == 180 then
    return 0
  else
    return -1
  end
end

local function cos_quarter(x)
  x = x % 360
  if x == 0 then
    return 1
  elseif x == 90 then
    return 0
  elseif x == 180 then
    return -1
  else
    return 0
  end
end

local function atan2deg(y,x)
  
  -- Works like atan2, but returns the angle in degrees and, returns
  -- exactly a multiple of 90 if x or y are zero

  if x == 0 then
    if y < 0 then
      return -90
    else
      return 90
    end
  elseif y == 0 then
    if x < 0 then
      return 180
    else
      return 0
    end
  else
    return atan2(y,x) * to_deg
  end
    
end

local function subarc (path, startx, starty, start_angle, delta, radius, trans, center_x, center_y)
  
  local end_angle = start_angle + delta
  local factor = tan (delta*to_rad/4) * 1.333333333333333333333 * radius
  
  local s1, c1, s190, c190, s2, c2, s290, c290

  if start_angle % 90 == 0 then
    s1, c1, s190, c190 = sin_quarter(start_angle), cos_quarter(start_angle), sin_quarter(start_angle+90), cos_quarter(start_angle+90)
  else
    local a1 = start_angle*to_rad
    s1, c1, s190, c190 = sin(a1), cos(a1), sin(a1+pi_half), cos(a1+pi_half)
  end

  if end_angle % 90 == 0 then
    s2, c2, s290, c290 = sin_quarter(end_angle), cos_quarter(end_angle), sin_quarter(end_angle-90), cos_quarter(end_angle-90)
  else
    local a2 = end_angle * to_rad
    s2, c2, s290, c290 = sin(a2), cos(a2), sin(a2-pi_half), cos(a2-pi_half)
  end
  
  local lastx, lasty = center_x + c2*radius, center_y + s2*radius

  path[#path + 1] = "curveto"
  path[#path + 1] = Coordinate.new (startx + c190*factor, starty + s190*factor)
  path[#path + 1] = Coordinate.new (lastx  + c290*factor, lasty  + s290*factor)
  path[#path + 1] = Coordinate.new (lastx, lasty)

  if trans then
    path[#path-2]:apply(trans)
    path[#path-1]:apply(trans)
    path[#path  ]:apply(trans)
  end
  
  return lastx, lasty, end_angle
end



local function arc (path, start, start_angle, end_angle, radius, trans, centerx, centery)
  
  -- @param path is the path object
  -- @param start is the start coordinate
  -- @param start_angle is given in degrees
  -- @param end_angle is given in degrees
  -- @param radius is the radius
  -- @param trans is an optional transformation matrix that gets applied to all computed points
  -- @param centerx optionally: x-part of the center of the circle
  -- @param centery optionally: y-part of the center of the circle
  
  local startx, starty = start.x, start.y
  
  -- Compute center:
  centerx = centerx or startx - cos(start_angle*to_rad)*radius
  centery = centery or starty - sin(start_angle*to_rad)*radius
  
  if start_angle < end_angle then
    -- First, ensure that the angles are in a reasonable range:
    start_angle = start_angle % 360
    end_angle   = end_angle % 360
    
    if end_angle <= start_angle then
      -- In case the modulo has inadvertedly moved the end angle
      -- before the start angle:
      end_angle = end_angle + 360
    end
    
    -- Ok, now create a series of arcs that are at most quarter-cycles:
    while start_angle < end_angle do
      if start_angle + 179 < end_angle then
	-- Add a quarter cycle:
	startx, starty, start_angle = subarc(path, startx, starty, start_angle, 90, radius, trans, centerx, centery)
      elseif start_angle + 90 < end_angle then
	-- Add 60 degrees to ensure that there are no small segments
	-- at the end
	startx, starty, start_angle = subarc(path, startx, starty, start_angle, (end_angle-start_angle)/2, radius, trans, centerx, centery)
      else
	subarc(path, startx, starty, start_angle, end_angle - start_angle, radius, trans, centerx, centery)
	break
      end
    end
    
  elseif start_angle > end_angle then
    -- First, ensure that the angles are in a reasonable range:
    start_angle = start_angle % 360
    end_angle   = end_angle % 360
    
    if end_angle >= start_angle then
      -- In case the modulo has inadvertedly moved the end angle
      -- before the start angle:
      end_angle = end_angle - 360
    end
    
    -- Ok, now create a series of arcs that are at most quarter-cycles:
    while start_angle > end_angle do
      if start_angle - 179 > end_angle then
	-- Add a quarter cycle:
	startx, starty, start_angle = subarc(path, startx, starty, start_angle, -90, radius, trans, centerx, centery)
      elseif start_angle - 90 > end_angle then
	-- Add 60 degrees to ensure that there are no small segments
	-- at the end
	startx, starty, start_angle = subarc(path, startx, starty, start_angle, (end_angle-start_angle)/2, radius, trans, centerx, centery)
      else
	subarc(path, startx, starty, start_angle, end_angle - start_angle, radius, trans, centerx, centery)
	break
      end
    end
    
  -- else, do nothing
  end
end


---
-- Appends an arc (as in the sense of ``a part of the circumference of
-- a circle'') to the path. You may optionally provide a
-- transformation matrix, which will be applied to the arc. In detail,
-- the following happens: We first invert the transformation
-- and apply it to the start point. Then we compute the arc
-- ``normally'', as if no transformation matrix were present. Then we
-- apply the transformation matrix to all computed points.   
--
-- @function Path:appendArc(start_angle,end_angle,radius,trans)
--
-- @param start_angle The start angle of the arc. Must be specified in
-- degrees. 
-- @param end_angle the end angle of the arc.
-- @param radius The radius of the circle on which this arc lies.
-- @param trans A transformation matrix. If |nil|, the identity
-- matrix will be assumed.

function Path:appendArc(start_angle,end_angle,radius, trans)
  
  local start = rigid(self[#self])
  assert(type(start) == "table", "trying to append an arc to a path that does not end with a coordinate")
  
  if trans then
    start = start:clone()
    start:apply(Transform.invert(trans))
  end

  arc (self, start, start_angle, end_angle, radius, trans)
end




---
-- Appends a clockwise arc (as in the sense of ``a part of the circumference of
-- a circle'') to the path such that it ends at a given point. If a
-- transformation matrix is given, both start and end point are first
-- transformed according to the inverted transformation, then the arc
-- is computed and then transformed back.
--
-- @function Path:appendArcTo(target,radius_or_center,clockwise,trans)
--
-- @param target The point where the arc should end.
-- @param radius_or_center If a number, it is the radius of the circle
-- on which this arc lies. If it is a |Coordinate|, this is the center
-- of the circle.
-- @param clockwise If true, the arc will be clockwise. Otherwise (the
-- default, if nothing or |nil| is given), the arc will be counter
-- clockise. 
-- @param trans A transformation matrix. If missing,
-- the identity matrix is assumed.


function Path:appendArcTo (target, radius_or_center, clockwise, trans)

  local start = rigid(self[#self])
  assert(type(start) == "table", "trying to append an arc to a path that does not end with a coordinate")

  local trans_target = target
  local centerx, centery, radius
  
  if type(radius_or_center) == "number" then
    radius = radius_or_center
  else
    centerx, centery = radius_or_center.x, radius_or_center.y
  end
  
  if trans then
    start = start:clone()
    trans_target = target:clone()
    local itrans = Transform.invert(trans)
    start:apply(itrans)
    trans_target:apply(itrans)
    if centerx then
      local t = radius_or_center:clone()
      t:apply(itrans)
      centerx, centery = t.x, t.y
    end
  end
  
  if not centerx then
    -- Compute center
    local dx, dy = target.x - start.x, target.y - start.y

    if abs(dx) == abs(dy) and abs(dx) == radius then
      if (dx < 0 and dy < 0) or (dx > 0 and dy > 0) then
	centerx = start.x
	centery = trans_target.y
      else
	centerx = trans_target.x
	centery = start.y
      end
    else
      local l_sq = dx*dx + dy*dy
      if l_sq >= radius*radius*4*0.999999 then
	centerx = (start.x+trans_target.x) / 2
	centery = (start.y+trans_target.y) / 2
	assert(l_sq <= radius*radius*4/0.999999, "radius too small for arc")
      else
        -- Normalize
	local l = sqrt(l_sq)
	local nx = dx / l
	local ny = dy / l
	
	local e = sqrt(radius*radius - 0.25*l_sq) 
	
	centerx = start.x + 0.5*dx - ny*e
	centery = start.y + 0.5*dy + nx*e
      end
    end
  end
  
  local start_dx, start_dy, target_dx, target_dy =
    start.x - centerx, start.y - centery,
    trans_target.x - centerx, trans_target.y - centery
  
  if not radius then
    -- Center is given, compute radius:
    radius_sq = start_dx^2 + start_dy^2

    -- Ensure that the circle is, indeed, centered:
    assert (abs(target_dx^2 + target_dy^2 - radius_sq)/radius_sq < 1e-5, "attempting to add an arc with incorrect center")
    
    radius = sqrt(radius_sq)
  end

  -- Compute start and end angle:
  local start_angle = atan2deg(start_dy, start_dx) 
  local end_angle = atan2deg(target_dy, target_dx) 

  if clockwise then
    if end_angle > start_angle then
      end_angle = end_angle - 360
    end
  else
    if end_angle < start_angle then
      end_angle = end_angle + 360
    end
  end
  
  arc (self, start, start_angle, end_angle, radius, trans, centerx, centery)

  -- Patch last point to avoid rounding problems:
  self[#self] = target
end




--
-- @return The Path as string.
--
function Path:__tostring()
  local r = {}
  local i = 1
  while i <= #self do
    local p = self[i]
    
    if p == "lineto" then
      r [#r+1] = " -- " .. tostring(rigid(self[i+1]))
      i = i + 1
    elseif p == "moveto" then
      r [#r+1] = " " .. tostring(rigid(self[i+1]) )
      i = i + 1
    elseif p == "curveto" then
      r [#r+1] = " .. controls " .. tostring(rigid(self[i+1])) .. " and " ..
      tostring(rigid(self[i+2])) .. " .. " .. tostring(rigid(self[i+3]))
      i = i + 3
    elseif p == "closepath" then
      r [#r+1] = " -- cycle"
    else
      error("illegal path command")
    end
    i = i + 1
  end
  return table.concat(r)
end




-- Done

return Path
