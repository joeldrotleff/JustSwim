## What is this?
Native Apple Watch app for swimming


## The problem it solves
Default workout app isn't accurate at timing auto sets. It's a critical issue to me because I want to see if I've gotten faster over time.

## How it works
Uses WorkoutKit (Apple's framework) for 90% of the workout detection, then bolts on its own custom bits for the set tracking

## Custom Set Tracking Part
The user taps their fingers together to trigger the start of a set. (Can't tap the screen because of water lock - touch screens don't work well in water).

User hits the wall to end the set for precision, then double taps to confirm.

## Technologies Used:
SwiftUI, CoreMotion
