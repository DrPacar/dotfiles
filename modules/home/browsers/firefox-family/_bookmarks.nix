{
  force = true;
  settings = [
    {
      name = "toolbar";
      toolbar = true;
      bookmarks = [
        
        # --- Folders ---
        {
          name = "AI Tools";
          bookmarks = [
            { name = "Claude";           url = "https://claude.ai/"; }
            { name = "Gemini";           url = "https://gemini.google.com/"; }
            { name = "ChatGPT";          url = "https://chatgpt.com/"; }
          ];
        }
        {
          name = "AT";
          bookmarks = [
            { name = "Post Briefkasten"; url = "https://www.e-brief.at/fe/deliveries"; }
            { name = "Finanzonline";     url = "https://finanzonline.bmf.gv.at"; }
            { name = "ID Austria";       url = "https://oesterreich.gv.at"; }
          ];
        }

        # --- Direct Links ---
        { name = "YouTube";              url = "https://www.youtube.com/"; }
        { name = "GitHub Repos";         url = "https://github.com/DrPacar?tab=repositories"; }
        
      ];
    }
  ];
}
