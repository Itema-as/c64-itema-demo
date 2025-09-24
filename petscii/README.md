# Designing levels and sprites

Use https://petscii.krissz.hu/ to design levels and sprites. Load the itemaball.pe file as the starting point. 

Save as *.pe file
in order to be able to load and the entire project. 


# Generating level files

1. Load `itemaball.pe` found in this folder
2. Edit levels using "Screens" in the PETSCII editor
3. Export levels to `*.seq` files
   - intro screen must be named 'intro.seq'
   - level screens must be named 'level_<n>.seq'
4. Update 'convert-screens.sh' if required
5. Run 'convert-screens.sh'

