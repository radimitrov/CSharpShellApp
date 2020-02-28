<b>Why does the application show a compilation error? Doesn't it support /language feature here/?</b><br/>
The app uses the Roslyn compiler - full C# 8 compilation support.<br/>
Any compilation related error encountered is a syntax or logic error in your own code and thefore only adressable by you.<br/>
<br/>
<b>Does the app support GUI?</b><br/>
Yes, Xamarin.Forms.<br/>
<br/>
<b>Does the app support Windows.Forms?</b><br/>
No. Android OS != Windows.<br/>
It is impossible for Android to support Windows.Forms due to extreme incompatibility issues (no touch, no applicable mapping for most controls and incompatable layouts for starters)<br/>
<br/>
<b>Why can't I close file/project?</b><br/>
Redundant operation. They are closed automatically when you open or create a new one.<br/>
<br/>
<b>Why was the application closed when when returning to foreground after a while?</b><br/>
It is a RAM intensive app. Other RAM intensive apps you use (like a web browser) will cause the system to kill resource consuming background processes like C# Shell when your RAM gets low.<br/>
<br/>
<b>Does the app support NuGet packages?</b><br/>
Yes, but not fully. Anything containing library dependencies that aren't .NET/C# won't work. Including Android bindings, at least for now.<br/>
<br/>
<b>Does the app support databases?</b><br/>
In general, yes. However a full ORM like Entity isn't properly supported.<br/>
<br/>
<b>Does the app support scripts?</b><br/>
No, that might be confusing for people who aren't yet familiar with the C# language.<br/>
<br/>
<b>Does the app support creating class or page/xaml files?</b><br/>
Yes, from the ""+"" in the left project menu. It doesn't support automatically making classes in an already existing file, since that is the same as typing it somewhere.<br/>
<br/>
<b>Can I reference a ".dll" file?</b><br/>
Yes, from the "+" in the left project menu.<br/>
<br/>
<b>Does the app support external keyboards?</b><br/>
Yes. Including a few custom shortcuts.<br/>
<br/>
<b>How to fix "You need to declare the permission..." ?</b><br/>
You need to declare it from the "APK project settings" and then export as APK.<br/>
<br/>
<b>Is the app free?</b><br/>
Yes and no. There is a 14 day period where it is completely free in any situation.<br/>
After that there are 2 options for all functionality:<br/>
   1. A single time purchase for about 2 USD.<br/>
   2. An ad-supported model that actively requires an internet connection.
