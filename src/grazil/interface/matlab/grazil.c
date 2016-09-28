#include "mex.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "grazilpath.h"

static int setLuaPath(lua_State* L, const char* path)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    char str[1024];
    const char *s = lua_tostring(L, -1); 
    strcpy(str, s);
    strcat(str, ";");
    strcat(str, path);
    strcat(str, "/?.lua");
    /*printf("%s\n",str);*/
    lua_pop( L, 1 );
    lua_pushstring(L, str);
    lua_setfield(L, -2, "path");
    lua_pop(L, 1);
    return 0;
}

static void getGraphFromLua(char *buf, int n, double *outMatrix) {
    lua_State *L;
    L = luaL_newstate();
    luaL_openlibs(L);
    
    setLuaPath(L,GRAZILPATH);
    
    int status,result;
    status = luaL_loadfile(L, buf);
    if (status) {
        mexErrMsgIdAndTxt( "MATLAB:grazil:loadError", lua_tostring(L, -1));
    }
    
    lua_newtable(L);
    lua_pushstring(L, "n");   /* Push the table index */
    lua_pushinteger(L, n); /* Push the cell value */
    lua_rawset(L, -3);      /* Stores the pair in the table */
    lua_setglobal(L, "params");
    
    result = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (result) {
        mexErrMsgIdAndTxt( "MATLAB:grazil:runError", lua_tostring(L, -1));
    }
    
    int i,u,v;
    /*lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        u = lua_tonumber(L,-1);
        lua_pop(L, 1);
        
        lua_next(L, -2);
        v = lua_tonumber(L,-1);
        lua_pop(L, 1);

        u--;v--;
        printf("edge (%d,%d)\n",u,v);
        outMatrix[n*u+v]=1;
    }*/
    lua_len(L,-1);
    int m = lua_tonumber(L,-1)/2;
    lua_pop(L, 1);
    for (i = 0; i < m; i++) {
        lua_rawgeti(L,-1,2*i+1);
        u = lua_tonumber(L,-1);
        lua_pop(L, 1);

        lua_rawgeti(L,-1,2*i+2);
        v = lua_tonumber(L,-1);
        lua_pop(L, 1);
        
        u--;v--;
        printf("edge (%d,%d)\n",u,v);
        outMatrix[n*u+v]=1;
    }
    
    lua_close(L);
}

void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[])
{
    double *outMatrix;              /* output matrix */
    double ret;

    char *buf;
    size_t buflen;
    int status;
    int n;
    
    /* Check for proper number of input and output arguments */
    if (nrhs != 2) { 
            mexErrMsgIdAndTxt( "MATLAB:grazil:invalidNumInputs", 
                "Two input arguments required.");
    } 
    if (nlhs > 1) {
            mexErrMsgIdAndTxt( "MATLAB:grazil:maxlhs",
                "Too many output arguments.");
    }

    buflen = mxGetN(prhs[0]) + 1;
    buf = mxMalloc(buflen);
    
    /* Copy the string data into buf. */ 
    status = mxGetString(prhs[0], buf, (mwSize)buflen);   

    n = mxGetScalar(prhs[1]);

    /* create the output matrix */
    plhs[0] = mxCreateDoubleMatrix(n,n,mxREAL);
    /* get a pointer to the real data in the output matrix */
    outMatrix = mxGetPr(plhs[0]);

    getGraphFromLua(buf,n,outMatrix);
    
    /* When finished using the string, deallocate it. */
    mxFree(buf);
}
