#  MistApi for iOS

## static library build process

* Select target "UniversalBuild", and perform "Build". The final output, static lib file (.a) and include files, will appear into MistApi/universal_lib
* Note that the library is build "universally", so you can run both on simulator and iphone platforms.

## How to use in your app


### Including lib and headers into the project

* Symlink MistApi/universal_lib to a folder in your project, e.g. "lib". 
** The advantage with a symlink is that if you make changes in to MistApi lib, then you can take those changes into use simply by re-building your app.
** Alternatively a copy can also be made

* Add library to your project: Under your project target, under "Linked frameworks and libraries" add the file libMistApi.a from lib folder
* Under target Build settings (all) > Search paths > header search paths add ${PROJECT_DIR}/lib/include as recursive
* Under Build settings (all) > Search paths > library search paths, add ${PROJECT_DIR}/lib

* ToDo: CocoaPods 

### Starting Wish and MistApi


## Information on how the project was set up in Xcode

### Adding library header files

When creating new header files that we wish to include in the final build (along with the static library), we add them to MistApi > Target: MistApi > Build Phases > Copy files 

### other info
The project has been created as a "cocoa touch static library" project in Xcode.

wish-c99 and mist-c99 has been added as subrepositories, and each of the source catalogue has been imported into the project using the "File/Add files..." menu. It is important to check the "Create groups" option in the add files dialog, in order actually add them as source files for the build system.

Also the headers must be added into the build header search path:
MistApi > target MistApi > Build settings > User header search paths

In order to build both for iphoneos and simulator platforms, a custom build script is created. The build script can be seen under "MistApi > Targets: UniversalBuild > Build Phases > Run script".

The target MistApi has been added as a dependency for this UniversalBuild project.

Reference: https://www.raywenderlich.com/41377/creating-a-static-library-in-ios-tutorial
