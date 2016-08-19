// Lua stuff:
#include <lauxlib.h>

// C stuff:
#include <stdlib.h>
#include <string.h>

// Lingeling stuff:

#include "lglib.h"



static int Solver_new(struct lua_State *state) {

  LGL ** userdata = (LGL**) lua_newuserdata(state, sizeof(LGL*));

  lua_pushvalue(state, lua_upvalueindex(1)); // Push the Solver class
  lua_setmetatable(state, 1);
  
  *userdata = lglinit ();

  return 1;
}

static int Solver_gc(struct lua_State *state) {

  LGL** lgl_ptr = lua_touserdata(state, 1);

  if (lgl_ptr) {
    lglrelease(*lgl_ptr);
  }

  return 0;
}


static LGL* get_lgl(struct lua_State *state) {
  
  if (!lua_getmetatable(state,1)) {
    lua_pushliteral(state, "Invalid self argument");
    lua_error(state);    
  }

  lua_pushvalue(state, lua_upvalueindex(1)); // Push the Solver class
  if (!lua_compare(state, -1, -2, LUA_OPEQ)) {
    lua_pushliteral(state, "Invalid self argument");
    lua_error(state);    
  }

  lua_pop(state, 2);

  LGL** lgl_ptr = lua_touserdata(state, 1);
  if (!lgl_ptr) {
    lua_pushliteral(state, "Invalid self argument");
    lua_error(state);    
  }

  return *lgl_ptr;
}

static int Solver_addDIMACSSeqence(struct lua_State *state) {

  LGL* lgl = get_lgl(state);

  int n = lua_gettop (state);
  int success;
  for (int i = 2; i <= n; i++) {
    int type = lua_type (state, i);
    if (type == LUA_TTABLE) {
      // Iterate over the entries of the table
      lua_len(state, i);
      lua_Integer len = lua_tointeger(state, -1);
      lua_pop(state, 1);
      for (int j = 1; j <= len; j++) {
	lua_geti(state, i, j);
	lua_Integer c = lua_tointegerx (state, -1, &success);
	if (!success) {
	  lua_pushliteral(state, "Illegal argument in DIMACS sequence");
	  lua_error(state);    
	}
	lgladd (lgl, c);
	lua_pop(state, 1);	
      }      
    } else {
      lua_Integer c = lua_tointegerx (state, i, &success);
      if (!success) {
	lua_pushliteral(state, "Illegal argument in DIMACS sequence");
	lua_error(state);    
      }
      lgladd (lgl, c);
    }
  }

  return 0;
}


static int Solver_isSatisfiable(struct lua_State *state) {

  LGL* lgl = get_lgl(state);
  if (lglsat (lgl) == LGL_SATISFIABLE)
    lua_pushboolean(state, 1);
  else
    lua_pushboolean(state, 0);
  return 1;
}


static int Solver_query(struct lua_State *state) {
  
  LGL* lgl = get_lgl(state);

  if (lua_gettop(state) != 2) {
    lua_pushliteral(state, "Query must be called with arguments self and a table");
    lua_error(state);
  }

  int type = lua_type(state, 2);

  if (type != LUA_TTABLE) {
    lua_pushliteral(state, "Query must be called with a table argument");
    lua_error(state);
  }

  lua_newtable (state); // Stack pos 3

  lua_len(state, 2);
  lua_Integer len = lua_tointeger(state, -1);
  lua_pop(state, 1);
  for (int j = 1; j <= len; j++) {
    lua_geti(state, 2, j);
    lua_Integer c = lua_tointeger (state, -1);
    if (!c) {
      lua_pushliteral(state, "Array may contain only non-zero integers");
      lua_error(state);    
    }
    lua_pop(state,1);
    lua_pushinteger(state, lglderef(lgl, c));
    lua_seti(state, 3, j);
  }     

  return 1;
}




int luaopen_grazil_bindings_lingeling_Solver (struct lua_State *state) {

  
  // Create the Solver class table:
  lua_createtable (state, 0, 6);

  lua_pushvalue(state, -1); // Make the table an upvalue
  lua_pushcclosure(state, Solver_new, 1);
  lua_setfield(state, -2, "new");

  lua_pushvalue(state, -1); // Make the table an upvalue
  lua_pushcclosure(state, Solver_addDIMACSSeqence, 1);
  lua_setfield(state, -2, "addDIMACSequence");

  lua_pushvalue(state, -1); // Make the table an upvalue
  lua_pushcclosure(state, Solver_isSatisfiable, 1);
  lua_setfield(state, -2, "isSatisfiable");

  lua_pushvalue(state, -1); // Make the table an upvalue
  lua_pushcclosure(state, Solver_query, 1);
  lua_setfield(state, -2, "query");

  lua_pushcfunction(state, Solver_gc);
  lua_setfield(state, -2, "__gc");

  lua_pushvalue(state, -1);
  lua_setfield(state, -2, "__index");

  return 1;
}

