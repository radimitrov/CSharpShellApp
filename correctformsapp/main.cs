using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Xamarin.Forms;

namespace CSharp_Shell
{

    public class Program 
    {
        public static void Main()
        {
        	Ui.RunOnUiThread(()=>
        	{
        		Ui.LoadApplication(new Application());
        	});
        }
    }
}
