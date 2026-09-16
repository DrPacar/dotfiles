{lib}: {
  lua = lib.generators.mkLuaInline;
  luaFunc = func:
    lib.generators.mkLuaInline ''
      function()
        ${func}
      end
    '';
  mod = "SUPER";
}
