#include "TrayUI.h"

#include <QApplication>
#include <QProcess>
#include <QTimer>
#include <QFileInfo>
#include <QDir>
#include <QInputDialog>

//PUBLIC
TrayUI::TrayUI() : QSystemTrayIcon(){
  qDebug() << "Starting Up System Updater Tray...";
  PerformingCheck = false; //initial value
  settings = new QSettings("PCBSD");
    settings->sync();
  watcher = new QFileSystemWatcher();
    connect(watcher, SIGNAL( fileChanged(QString) ), this, SLOT(watcherFileChange(QString)) ); //specific file changed
    connect(watcher, SIGNAL( directoryChanged(QString) ), this, SLOT(watcherDirChange()) ); //directory changed
	
  //Create the Menu
  mainMenu = new QMenu();
    this->setContextMenu( mainMenu ); 
    connect(mainMenu, SIGNAL(triggered(QAction*)), this, SLOT(slotItemClicked(QAction*)) );
  //Populate the menu
  QAction *tmp = mainMenu->addAction(QIcon(":/images/updated.png"), tr("Start the Update Manager") );
	tmp->setWhatsThis("sys");
  mainMenu->addSeparator();
  tmp = mainMenu->addAction(QIcon(":/images/appcafe.png"), tr("Start the AppCafe") );
	tmp->setWhatsThis("pkg");
  tmp = mainMenu->addAction(QIcon(":/images/warden.png"), tr("Start the Warden") );
	tmp->setWhatsThis("warden");
  mainMenu->addSeparator();
  tmp = mainMenu->addAction(QIcon(":/images/view-refresh.png"), tr("Check for Updates") );
	tmp->setWhatsThis("update");
  mainMenu->addSeparator();
  // - Now the special checkboxes
  runAtStartup = new QCheckBox(tr("Run At Startup"));
    runAtStartup->setChecked(settings->value("/PC-BSD/SystemUpdater/runAtStartup",true).toBool() );
    connect(runAtStartup, SIGNAL(clicked()), this, SLOT(slotRunAtStartupClicked()) );
  rasA = new QWidgetAction(this);
    rasA->setDefaultWidget(runAtStartup);
  mainMenu->addAction(rasA);
  showNotifications = new QCheckBox(tr("Display Notifications"));
    showNotifications->setChecked(settings->value("/PC-BSD/SystemUpdater/displayPopup",true).toBool() );
    connect(showNotifications, SIGNAL(clicked()), this, SLOT(slotShowMessagesClicked()) );
  snA = new QWidgetAction(this);
    snA->setDefaultWidget(showNotifications);
  mainMenu->addAction(snA);
  checkJails = new QCheckBox(tr("Check Jails"));
    checkJails->setChecked(settings->value("/PC-BSD/SystemUpdater/watchJails",false).toBool() );
    connect(checkJails, SIGNAL(clicked()), this, SLOT(slotCheckJailsClicked()) );
 cjA = new QWidgetAction(this);
    cjA->setDefaultWidget(checkJails);
  mainMenu->addAction(cjA);
  mainMenu->addSeparator();
  // - Now the quit option
  tmp = mainMenu->addAction(tr("Quit") );
	tmp->setWhatsThis("quit");
  //Initialize the backend systems  
  UpdateAUNotice(); //make sure that we get an icon/info right away
  QTimer::singleShot(30000, this, SLOT(checkForUpdates()) ); //Wait 30 seconds to perform the first update check
}

TrayUI::~TrayUI(){
  delete mainMenu;
  delete runAtStartup;
  delete showNotifications;
}

// ===============
//            PRIVATE
// ===============
void TrayUI::UpdateAUNotice(){
  QString val = pcbsd::Utils::getValFromPCBSDConf("AUTO_UPDATE").simplified().toLower();
  if(val=="all"){
    AUNotice = tr("Auto-Update: Everything");
  }else if(val=="security"){
    AUNotice = tr("Auto-Update: Security Only");
  }else if(val=="pkg"){
    AUNotice = tr("Auto-Update: Packages Only");
  }else if(val=="disabled"){
    AUNotice = tr("Auto-Update: Disabled");
  }else{ // "securitypkg" is default
    val = "securitypkg";
    AUNotice = tr("Auto-Update: Security & Packages");
  }
  AUval = val; //save this for later
  //Now add info about the most recent update attempt
  QStringList info = pcbsd::Utils::runShellCommand("beadm list -H").filter("-up-");
  if(!info.isEmpty()){
    AUNotice.append("\n"+tr("Last Update: %1") );
    AUNotice = AUNotice.arg( info.last().section("\t",4,5) ); //only put the date/time here
  }
  UpdateIcon();
}

// ===============
//     PRIVATE SLOTS
// ===============
void TrayUI::watcherDirChange(){
  bool check = false;
  if(lastDirCheck.isNull()){ 
    //First time this has had a ping - always run it once
    check = true;
  }else{
    //Check that it is a relevant flag that was updated
    QDir procdir(UPDATE_PROC_DIR);
      QFileInfoList flags = procdir.entryInfoList(QStringList() << UPDATE_PROC_FLAG_FILE_FILTER, QDir::Files, QDir::Time);
      for(int i=0; i<flags.length(); i++){
        if(lastDirCheck < flags[i].lastModified()){
	  check=true; 
	  break;
	}
      }
  }
  if(check){ QTimer::singleShot(0,this, SLOT(checkForUpdates()) );  }
  lastDirCheck = QDateTime::currentDateTime();
}

void TrayUI::watcherFileChange(QString file){
  if(file == PCBSD_CONF_FILE){
     UpdateAUNotice();
  }else if( file == SYSCACHE_LOG_FILE ){
    QTimer::singleShot(0,this, SLOT(checkForUpdates()) );
  }
}

void TrayUI::checkForUpdates(){
  if(PerformingCheck){ return; } //Already checking
  PerformingCheck = true;
  this->setIcon( QIcon(":/images/working.png") );
  //Verify that the proper files/dirs are currently being watched
  if(watcher->directories().isEmpty()){ watcher->addPath(UPDATE_PROC_DIR); }
  if(watcher->files().isEmpty()){ watcher->addPaths( QStringList() << SYSCACHE_LOG_FILE << PCBSD_CONF_FILE ); }
  //Simplification function to perform all checks
  SysStatus oldStat = CSTAT; //save a copy of the old status for a moment
  CSTAT = SysStatus();
    CSTAT.checkSystem(checkJails->isChecked());
  //Sync the icon/tooltip
  UpdateIcon();
  //Now show a popup message (if enabled and is a different status);
  if(CSTAT.changedFrom(oldStat) && settings->value("/PC-BSD/SystemUpdater/displayPopup",true).toBool() ){
    ShowMessage();
  }
  PerformingCheck = false;
}

void TrayUI::UpdateIcon(){
  this->setIcon( CSTAT.icon() );
  QString tt = CSTAT.tooltip();
  //Make any adjustments to the tooltip as necessary
  if(!CSTAT.complete && !CSTAT.updating){
    tt.append("\n\n"+AUNotice); //add info about scheduled/last update
  }
  this->setToolTip(tt);
}

void TrayUI::ShowMessage(){
  //Determine the message to show (if any)
  if(CSTAT.complete){
    bool ok = false;
    int hours = QInputDialog::getInt(0, tr("System Reboot Required"), tr("Time before next reminder (hours): "), 1, 0, 48, 1, &ok, Qt::Tool | Qt::WindowStaysOnTopHint);
    if(!ok){ hours = 1; }
    if(hours > 0){ QTimer::singleShot(hours*360000, this, SLOT(ShowMessage()) ); }
  }else if(CSTAT.updating){
    this->showMessage(tr("Starting updates"), "", QSystemTrayIcon::NoIcon, 1000); //1 second timer (minor message)
  }else if(AUval=="all"){ 
    return; //All updates handled automatically - don't show messages about them
  }else if(CSTAT.sys){
     this->showMessage(CSTAT.tooltip(),"",QSystemTrayIcon::Critical, 10000); //10 second timer
  }else if(CSTAT.sec){
    if(AUval.contains("security")){ return; } //will auto-update - skip message
    this->showMessage(tr("Updates Available"), CSTAT.tooltip(), QSystemTrayIcon::Critical, 10000); //10 second timer
  }else if(CSTAT.pkg){
     if(AUval.contains("pkg")){ return; } //will auto-update - skip message
    this->showMessage(tr("Updates Available"), CSTAT.tooltip(), QSystemTrayIcon::Warning, 5000); //5 second timer
  }else if(CSTAT.jail){
     this->showMessage(CSTAT.tooltip(), "", QSystemTrayIcon::Information, 1000); //1 second timer
  }
	
}

void TrayUI::BackendResync(){
  QProcess::startDetached("syscache startsync");
}

void TrayUI::launchApp(QString app){
  //Check for auto-launch
  if(app.isEmpty()){
    if(CSTAT.sys || CSTAT.sec || CSTAT.pkg ){ app = "sys"; } //all updates handles in a single utility now
    else if(CSTAT.jail){ app = "warden"; }
    else{ app = "pkg"; }
  }
  //Now Launch the proper application
  QString cmd;
  if(app=="sys"){
    cmd = "pc-su pc-updategui";
  }else if(app=="pkg"){
    cmd = "pc-softwaremanager";
  }else if(app=="warden"){
    cmd = "pc-su warden gui";
  }else{ 
    return; //invalid app specified
  }
  qDebug() << "Startup External Application:" << cmd;
  QProcess::startDetached(cmd);
}


void TrayUI::slotItemClicked(QAction* act){
  QString code = act->whatsThis();
  if(code=="quit"){
    //Close the tray
    slotClose();
  }else if(code=="update"){
    //Re-check for updates by syscache
    BackendResync();
  }else if(code.isEmpty()){
    return;
  }else{
    //Launch one of the external applications
    launchApp(code);
  }
  
}

void TrayUI::slotTrayClicked(QSystemTrayIcon::ActivationReason reason){
  if(reason == QSystemTrayIcon::Context){
    this->contextMenu()->popup(QCursor::pos());
  }else{
    launchApp();
  }
}

void TrayUI::slotRunAtStartupClicked(){
  settings->setValue("/PC-BSD/SystemUpdater/runAtStartup",runAtStartup->isChecked());
  settings->sync(); //make sure to save to file right away
  //Now be sure to also save this to the PC-BSD system registry so it is acted upon properly
  QString cmd = "pbreg set /PC-BSD/SystemUpdater/runAtStartup false";
  if(runAtStartup->isChecked()){ cmd.replace(" false", " true"); }
  QProcess::startDetached(cmd);
}

void TrayUI::slotShowMessagesClicked(){
  settings->setValue("/PC-BSD/SystemUpdater/displayPopup",showNotifications->isChecked());	
  settings->sync(); //make sure to save to file right away
}

void TrayUI::slotCheckJailsClicked(){
  settings->setValue("/PC-BSD/SystemUpdater/checkJails",checkJails->isChecked());
  settings->sync();
  QTimer::singleShot(0,this, SLOT(checkForUpdates()) ); //since the types of checks has changed	
}

void TrayUI::slotClose(){
  qDebug() << "pc-systemupdatertray: Closing down...";
  QApplication::exit(0);
}

void TrayUI::slotSingleInstance(){
  this->show();
    //do nothing else at the moment
}
