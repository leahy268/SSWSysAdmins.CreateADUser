using Microsoft.IdentityModel.Protocols;
using System.Configuration;
using System.IO;
using System.Management.Automation;
using System.ServiceProcess;

namespace SSW.CreateADUser
{
    public partial class Watcher : ServiceBase
    {
        public Watcher()
        {
            InitializeComponent();
        }

        protected override void OnStart(string[] args)
        {
            FolderWatcher.Path = ConfigurationManager.AppSettings["Path"];
        }

        private void FolderWatcher_Created(object sender, FileSystemEventArgs e)
        {
            // Run PowerShell Script
            PowerShell shell = PowerShell.Create();
            string script = $@"Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Unrestricted -File C:\AutoCreateADUser\CreateADUser.ps1 -Verb RunAs'";
            shell.Commands.AddScript(script);
            shell.Invoke();
        }
    }
}
