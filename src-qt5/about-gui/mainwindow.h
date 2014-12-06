/**************************************************************************
*   Copyright (C) 2012 by Yuri Momotyuk                                   *
*   yurkis@gmail.com                                                      *
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

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDialog>
#include <QProcess>

namespace Ui {
class MainWindow;
}

class MainWindow : public QDialog
{
    Q_OBJECT
    
public:
    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();
    
    bool checkNG();
    bool checkNGPackage(QString name, QString& outVer);
    void addDEItem(QString name, QString version);

public slots:
    void slotSingleInstance();
    void slotPackagesFinished();

private slots:
    void on_pushButton_2_clicked();

    void on_BackButton_clicked();

    void slotReadPkg();    

    void on_pushButton_clicked();

    void on_BackButton_2_clicked();

private:
    Ui::MainWindow *ui;
    QProcess* pkginfo;
};

#endif // MAINWINDOW_H
