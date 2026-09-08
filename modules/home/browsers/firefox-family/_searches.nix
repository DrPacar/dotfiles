{
  force = true;
  default = "google";

  engines = {
    "google".metaData.alias = "@g";

    "youtube" = {
      urls = [
        {
          template = "https://www.youtube.com/results";
          params = [
            {
              name = "search_query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = "https://www.youtube.com/favicon.ico";
      definedAliases = ["@yt"];
    };

    "github" = {
      urls = [
        {
          template = "https://github.com/search";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = "https://github.githubassets.com/favicons/favicon.png";
      definedAliases = ["@gh"];
    };
  };
}
