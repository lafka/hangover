-- MODEL ------------------------
-- objects:
--   - track
--     - stations, length - artist - path - id - mood - {first,last} played, playcount
--   - selector
--     - station - name - criteria - mood - happy
--   - program
--     - station - start - stop - selector - items
--     - recurring -> weekly, daily, blank
--   - stations
--     - name - selector
---------------------------------
-- Goals:
-- search(track{key=val},sort,limit,paginate)
-- unique add(artist,track,{key=val})

require "tokyocabinet"
require "os"
local u = require "lib/util"

module("tracks", package.seeall)

local default_station = "oslobass"

function tracks:init(file)
  file = file or "tracks.tch"
  trk = tokyocabinet.tdbnew()
  if not trk:open(file, trk.OWRITER + trk.OCREAT) then
    ecode = trk:ecode() 
    print("database open error: " .. trk:errmsg(ecode))
  end
end

tracks:init() 
-- fix this stupidity. if you spell the query type wrong, you get nothing, no warnings either.
local q = tokyocabinet.tdbqrynew(trk)
local op = {
  -- string
  equal     = q.TDBQCSTREQ,
  inclusive = q.TDBQCSTRSTRINC,
  begins    = q.TDBQCSTRBW,
  ends      = q.TDBQCSTREW,
  all       = q.TDBQCSTRAND,
  one       = q.TDBQCSTROR,
  eqone     = q.TDBQCSTROREQ,
  -- numeric
  eq        = q.QCNUMEQ,
  gt        = q.QCNUMGT,
  ge        = q.QCNUMGE,
  lt        = q.QCNUMLT,
  le        = q.QCNUMLE,
  tween     = q.QCNUMBT,
  numor     = q.QCNUMOREQ,
  -- fulltext
  phrase    = q.QCFTSPH,
  alltokens = q.QCFTSAND,
  onetoken  = q.QCFTSOR,
  compound  = q.QCFTSEX,
  -- flags
  negate    = q.QCNEGATE,
  noindex   = q.QCNOIDX,
}
local sort = {
  lexic     = q.QOSTRASC,
  reverse   = q.QOSTRDESC,
  increasing= q.QONUMASC,
  decreasing= q.QONUMDESC,
}

function tracks:put(pkey,cols)
  if not trk:put(pkey, cols) then
    ecode = trk:ecode()
    return nil,nil,trk:errmsg(ecode)
  else
    return pkey, cols
  end
end

-- tracks must have a name and can have any other tags, passed as table
-- (artist,track) pair is unique
-- returns: trackid,entry,error
function tracks:add(artist,track, cols) 
  cols = cols or {}
  res = tracks:search({artist = artist, track = track}, op.equal)
  for i,v in pairs(res) do
     return tracks:update(i,cols)
  end
  pkey = trk:genuid()
  cols.track   = track
  cols.artist  = artist
  cols.added   = os.time()
  cols.station = cols.station or default_station
  return tracks:put(pkey, cols)
end

-- search within the database
-- you can specify a entry limit and which page of the
-- result set you want to receive.
-- returns array [id]={result}
-- FIXME: search query is really (key, val, op) triplet
-- how to represent this in the API?
function tracks:search(query, limit, page, order, qop)
  q = tokyocabinet.tdbqrynew(trk)
  query = query or {station=default_station}
  limit = limit or 25
  page = page or 1
  order = order or {"added", sort.decreasing}
  qop = qop or op.inclusive
  skip = (page-1)*limit
  if type(order) ~= "table" then
    order = {"added", order}
  end
  q:setlimit(limit,skip)

  for k,v in pairs(query) do
    q:addcond(k, qop, v)
  end
  result = q:search()
  rset = {}
  for i,v in ipairs(result) do
    rawset(rset,v,tracks:get(v))
  end
  return rset
end

-- search wrapped and simplified
function tracks:gsearch(query, limit, page)
  
end
  
function tracks:dump()
  trk:iterinit()
  local key, value, accu
  accu = {}
  while true do
    key = trk:iternext()
    if not key then break end
    value = trk:get(key)
    table.insert(accu,value)
  end
  return u.dump(accu)
end

function tracks:get(pkey)
  return trk:get(pkey)
end

function tracks:update(pkey, cols)
  p = tracks:get(pkey)
  for k,v in pairs(p) do
    cols[k] = v
  end
  cols.updated = os.time()
  return tracks:put(pkey,cols)
end

-- return result with only fields
function tracks.filter(result, fields)
  local res = {}
  for k,v in pairs(result) do
    local one = {}
    for i,f in pairs(fields) do
      one[f] = v[f]
    end
    res[k] = one
  end
  return res
end
    
tracks:add("yo","mama", {foo="bar"})
tracks:add("world","musack", {foo="baz"})

u.out(tracks:dump())
return tracks
