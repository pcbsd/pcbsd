/**************************************************************************
*   Copyright (C) 2014 by Yuri Momotyuk                                   *
*   yurkis@pcbsd.org                                                      *
*                                                                         *
*   Permission is hereby granted, free of charge, to any person obtaining *
*   a copy of this software and associated documentation files (the       *
*   "Software"), to deal in the Software without restriction, including   *
*   without limitation the rights to use, copy, modify, merge, publish,   *
*   distribute, sublicense, and/or sell copies of the Software, and to    *
*   permit persons to whom the Software is furnished to do so, subject to *
*   the following conditions:                                             *
*                                                                         *
*   The above copyright notice and this permission notice shall be        *
*   included in all copies or substantial portions of the Software.       *
*                                                                         *
*   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *
*   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    *
*   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*
*   IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR     *
*   OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, *
*   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR *
*   OTHER DEALINGS IN THE SOFTWARE.                                       *
***************************************************************************/

#include "mainwindow.h"
#include "ui_mainwindow.h"

#include "kblayoutselectdialog.h"

#include <QDebug>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QDir>

using namespace pcbsd::keyboard;

const char* const USER_STARTUP_FILE = "/.xprofile";

///////////////////////////////////////////////////////////////////////////////
MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    ks = currentSettings();
    qDebug()<<pcbsd::keyboard::currentSettings().xkbString();

    fillKbModels();
}

///////////////////////////////////////////////////////////////////////////////
MainWindow::~MainWindow()
{
    delete ui;
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::fillKbModels()
{
    allKbModels = possibleModels();
    for(int i=0; i<allKbModels.size(); i++)
    {
        QVariant udata;
        udata.setValue(allKbModels[i]);
        ui->kbModelCB->addItem(modelDescription(allKbModels[i]), udata);        
        if (allKbModels[i] == ks.keyboardModel())
        {
            ui->kbModelCB->setCurrentIndex(ui->kbModelCB->count()-1);
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::updateSettings()
{
    ks.clearLayouts();
    ks.clearOptions();
    int idx = ui->kbModelCB->currentIndex();
    QVariant udata = ui->kbModelCB->itemData(idx);
    QString kb_model = udata.value<QString>();
    ks.setKeyboardModel(kb_model);
    ui->layoutsWidget->mergeSettings(ks);
    if (ui->optionsStack->currentIndex() == 0)
    {
        ui->simpleOptsWidget->mergeSettings(ks);
    }
    else
    {
        ui->optsWidget->mergeSettings(ks);
    }
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::on_advancedViewBtn_clicked()
{
   ui->simpleOptsWidget->mergeSettings(ks);
   ui->optsWidget->setSettings(ks);
   ui->optionsStack->setCurrentIndex(1);
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::on_simpleViewBtn_clicked()
{
    ui->optsWidget->mergeSettings(ks);
    ui->simpleOptsWidget->setSettings(ks);
    ui->optionsStack->setCurrentIndex(0);
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::on_applyBtn_clicked()
{
    updateSettings();
    QProcess::execute(QString("setxkbmap ") + ks.xkbString());
    qDebug()<<ks.xkbString();
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::on_saveUserBtn_clicked()
{
    updateSettings();
    QStringList file_strings;
    QFile file(QDir::homePath() + USER_STARTUP_FILE);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text))
    {

        QTextStream fts(&file);
        while (!file.atEnd())
        {
            QString line = file.readLine();
            file_strings<<line;
        }

        for(int i=0; i<file_strings.size(); i++)
        {
            QString line = file_strings[i].trimmed();
            if (line.startsWith("setxkbmap"))
            {
                file_strings.removeAt(i);
            }
        }
        file.close();
    }//if .xprofile exists

    file_strings<<( QString("setxkbmap ") + ks.xkbString() + "\n");

    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
    {
        QTextStream out_fts(&file);
        for(int i=0; i<file_strings.size(); i++)
        {
            out_fts<<file_strings[i];
        }
    }
    file.close();

    QProcess::execute(QString("setxkbmap ") + ks.xkbString());
}

///////////////////////////////////////////////////////////////////////////////
void MainWindow::slotSingleInstance()
{
    this->hide();
    this->showNormal();
    this->activateWindow();
    this->raise();
}
