# Overview

This template is for a Flutter "starter" application.  It intends to have a curated list of the best packages to build a network connected application.  To get started, check the Development section.  Backend solutions are listed under Backend.

## Motivation

As we get a number of projects off the ground in Japan, we found we need to provide some starter project templates to potential customers so we can support training of dev teams on Flutter development.  Because most example code floating around on the web is tied to blog posts, sometimes these blogs are very old (any pre-dart 3.x code doesn't really work anymore) or hidden behind a medium login.  We intend to support this template and provide training to Japanese companies interested in building out their expertise in Dartlang and Flutter development for Mobile.

## Why Flutter

Great question, why Flutter instead of React Native, or QT, or Java?

The simple answer:

- portable on all platforms
- great UX out of the box
- perhaps strongest on the mobile platform development side of things
- great tools and documentation

## Why Dart

This is a good question ... why Dart?  Dart is modern.  Dart has a number of modern paradigms.  If you could boil it down to a few bullet points:

- portable: runs on most major platforms
- great tools and docs: the community is well supported, and there are very mature tools available
- easy to learn: it is easy to pick up if you already know one programming language.  Most similar to Swift.

## Development

- Flutter

On Mac, install using brew.

On Windows, use chocolatey (choco)

On Linux, use a package manager

- XCode on Mac for iOS development
- Android Studio for Android on all the other platforms

Once installed, run flutter doctor.  Fix anything mentioned.

### iOS Dev

iOS development is only available on Mac OS X.  On iOS for a first time setup, you will need hours.  XCode is a long slow download.  Xcode commmand line tools take awhile.

Make sure to install cocoapods: sudo gem install cocoapods
### Android dev

Android development is possible on Mac, Linux, and Windows.  Android studio will take under an hour.

## Build

go to the this directory.

- flutter build TARGET

where target is the target you are building for.

On Android, flutter build apk

To run on the device: 

flutter run TARGET

For iOS

- flutter build ios
- if the above fails due to certificates, run: open ios/Runner.xcworkspace

### App Distribution

on iOS, you will need to set up developer certificates.  For team development, usually a company will have an App Developer account set up at Apple.  Ask your company.   Android is much easier to use for testing.  

## Backend

TODO

## Attributions

- IoTone Japan https://iotonesite.ai
- An example application using [responsive_toolkit](https://github.com/Calpoog/responsive_toolkit).
