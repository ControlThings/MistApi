#  MistApi for iOS

## static library build process

* Select scheme "UniversalBuild", and perform "Product -> Build". The final output, static lib file (.a) and include files, will appear into MistApi/universal_lib
* Note that the library is build "universally", so you can run both on simulator and iphone platforms.
* The custom script responsible for producing this "universal build" can be seen under MistApi project settings, target "UniversalBuild" -> Build Phases -> Run script

## How to use MistApi with 'react-native-mist-library'

react-native-mist-library depends on this MistApi library, unfortunately for the time beign MistApi project is not set up as subrepo into rn mist-library. Instead you must update the library manually:

* Copy the libMistApi.a and include dir from universal_build to RN MistLibrary project's ios/lib directory.
* If you hve RN MistLibrary linked to the actual RN app project, you should make sure that RN MistLibrary is rebuilt after libMistApi.a is updated. This can be done by choosing the RN MistLibrary target/scheme and Product->clean.

## How to use in your app (Generic instructions)

* The minimum iOS version must be 11.0. This is because of the wifi functions.

### Including lib and headers into the project

* Symlink MistApi/universal_lib to a folder in your project, e.g. "lib". 
** The advantage with a symlink is that if you make changes in to MistApi lib, then you can take those changes into use simply by re-building your app.
** Alternatively a copy can also be made

* Add library to your project: Under your project target, under "Linked frameworks and libraries" add the file libMistApi.a from lib folder
* Under target Build settings (all) > Search paths > header search paths add ${PROJECT_DIR}/lib/include as recursive
* Under Build settings (all) > Search paths > library search paths, add ${PROJECT_DIR}/lib

* ToDo: CocoaPods 

### Starting Wish and MistApi

Run

    [MistPort launchWish];
    [MistPort launchMistApi];

to start Wish and MistApi. These should be run exactly once, and will raise an exception is run several times.

### Sandbox support

The initial Sandbox support implemented here is very rudimetary. You should be aware of its limitations.

* Only one sandbox is supported

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
