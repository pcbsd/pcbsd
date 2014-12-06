/****************************************************************************
** ui.h extension file, included from the uic-generated form implementation.
**
** If you want to add, delete, or rename functions or slots, use
** Qt Designer to update this file, preserving your code.
**
** You should not define a constructor or destructor in this file.
** Instead, write your code in functions called init() and destroy().
** These will automatically be called by the form's constructor and
** destructor.
*****************************************************************************/
#include "wizardRestore.h"
#include "ui_wizardRestore.h"
#include "backend.h"
#include <QMessageBox>
#include <QInputDialog>

#define SCRIPTDIR QString("/usr/local/share/pcbsd/pc-installgui")

void wizardRestore::programInit()
{
   connect(this,SIGNAL(currentIdChanged(int)),this,SLOT(slotCheckComplete()));
   connect(lineHostName,SIGNAL(textChanged(const QString)),this,SLOT(slotCheckComplete()));
   connect(lineUserName,SIGNAL(textChanged(const QString)),this,SLOT(slotCheckComplete()));
   connect(spinPort,SIGNAL(valueChanged(int)),this,SLOT(slotCheckComplete()));
}

void wizardRestore::slotClose()
{
  close();
}

void wizardRestore::accept()
{
  QString targetSys;
  targetSys = sysList.at(comboBoxRestoreSystem->currentIndex());

  QStringList rset;
  rset << lineHostName->text();
  rset << lineUserName->text();
  rset << QString::number(spinPort->value());
  rset << authKey;
  rset << targetSys;
  emit saved(rset);
  close();
}

// Logic checks to see if we are ready to move onto next page
bool wizardRestore::validatePage()
{
  switch (currentId()) {
     case Page_Intro:
         button(QWizard::NextButton)->setEnabled(true);
         return true;
     case Page_Host:
         if ( lineHostName->text().isEmpty() ) {
           button(QWizard::NextButton)->setEnabled(false);
           return false;
         }
         if ( lineUserName->text().isEmpty() ) {
           button(QWizard::NextButton)->setEnabled(false);
           return false;
         }
         // if we get this far, all the fields are filled in
         button(QWizard::NextButton)->setEnabled(true);
         return true;
     case Page_Auth:
         button(QWizard::NextButton)->setEnabled(true);
         return true;
     case Page_System:
	 if ( comboBoxRestoreSystem->currentText().isEmpty() ) {
           button(QWizard::NextButton)->setEnabled(false);
           return false;
         }
         button(QWizard::NextButton)->setEnabled(true);
         return true;
     case Page_Finish:
         button(QWizard::FinishButton)->setEnabled(true);
         return true;
     default:
         button(QWizard::NextButton)->setEnabled(true);
         return true;
  }

  return true;
}

void wizardRestore::slotCheckComplete()
{
   // Validate this page
   validatePage();
}

void wizardRestore::initializePage(int page)
{
  switch (page) {
     case Page_System:
       comboBoxRestoreSystem->clear();

       // Lets start the auth process
       if ( radioUSBAuth->isChecked() ) {
	  if ( ! getUSBAuth() ) {
	     QMessageBox::critical(this, tr("No keys found!"),
                                tr("No Auth keys could be found on that memory stick!\n"
                                   "Please try another USB stick or use password authentication."),
                                QMessageBox::Ok,
                                QMessageBox::Ok);	
	      return;
	  }
       } else {
	  if ( ! startPWAuth() ) {
	     QMessageBox::critical(this, tr("Connection failed!"),
                                tr("Could not connect to the backup server!\n"
                                   "Please check that the server is reachable and verify your user/password."),
                                QMessageBox::Ok,
                                QMessageBox::Ok);	
             button(QWizard::NextButton)->setEnabled(false);
	     return;
          }
        }

	if ( ! getSysList() ) {
	   QMessageBox::critical(this, tr("Connection failed!"),
                               tr("Could not connect to the backup server!\n"
                                  "Please check your hostname and that the backup server is reachable."),
                                QMessageBox::Ok,
                                QMessageBox::Ok);	
            button(QWizard::NextButton)->setEnabled(false);
	    return;
        }

       break;
     case Page_Finish:
       plainTextEditSummary->clear();
       plainTextEditSummary->appendPlainText(tr("Will restore from:"));
       plainTextEditSummary->appendPlainText("Host: " + lineHostName->text());
       plainTextEditSummary->appendPlainText("User: " + lineUserName->text());
       plainTextEditSummary->appendPlainText("Target System: " + comboBoxRestoreSystem->currentText());
       break;
   }
}

bool wizardRestore::getUSBAuth()
{
  QStringList keys, dispKeys;

  QProcess p;
  p.start(SCRIPTDIR + "/load-usb-key.sh", QStringList());
  while(p.state() == QProcess::Starting || p.state() == QProcess::Running) {
      p.waitForFinished(200);
      QCoreApplication::processEvents();
  }
  while (p.canReadLine())
      keys << p.readLine().simplified();

  // Did we find any key files?
  if ( keys.isEmpty() )
     return false;

  // Only a single key? Lets use that
  if ( keys.size() == 1 ) {
     authKey = keys.at(0);
     return true;
  }

  // More than one? Lets ask the user which one they want to use
  ////////////////////

  // Lets start by showing only the file-names
  for (int i = 0; i < keys.size(); ++i)
     dispKeys << keys.at(i).section("/", -1);

  bool ok;
  QString item = QInputDialog::getItem(this, tr("Select the SSH key to use"),
                                          tr("Key File:"), dispKeys, 0, false, &ok);

  if ( !ok || item.isEmpty() )
     return false;

  for (int i = 0; i < keys.size(); ++i)
     if ( item == keys.at(i).section("/", -1) )
     {
        authKey = keys.at(i);
        return true;
     }
  

  // We shouldn't get here
  qDebug() << "Invalid end of getUSBAuth()";
  return false;
}

bool wizardRestore::startPWAuth()
{
  QString cmd = "xterm -e \""+SCRIPTDIR+"/setup-ssh-keys.sh " + \
                lineUserName->text() + \
                " " + lineHostName->text() + \
                " " +QString::number(spinPort->value()) + "\"";
  system(cmd.toUtf8());
  
  if ( QFile::exists("/tmp/.ssh-auth-failed") )
     return false;

  // Looks like auth worked!
  return true;
}

bool wizardRestore::getSysList()
{
  sysList.clear();
  comboBoxRestoreSystem->clear();

  qDebug() << lineUserName->text() << lineHostName->text() << authKey;

  QStringList propList;
  QProcess p;
  p.start(SCRIPTDIR + "/get-zfs-restore-list.sh", QStringList() << lineUserName->text() << lineHostName->text() << QString::number(spinPort->value()) << authKey );
  while(p.state() == QProcess::Starting || p.state() == QProcess::Running) {
      p.waitForFinished(200);
      QCoreApplication::processEvents();
  }
  while (p.canReadLine())
      propList << p.readLine().simplified();

  if ( p.exitStatus() == QProcess::CrashExit || p.exitCode() != 0 )
     return false;

  // Lets start by showing only the systemNames
  for (int i = 0; i < propList.size(); ++i) {
     if ( ! propList.at(i).startsWith(".lp-props-" ) )
        continue;
     comboBoxRestoreSystem->addItem(propList.at(i).section("#", -1));
     sysList << propList.at(i);
  }

  return true;
}

