#ifndef NFSMANAGER_H
#define NFSMANAGER_H

#include <QMainWindow>

namespace Ui {
class NFSManager;
}

class NFSManager : public QMainWindow
{
    Q_OBJECT

public:
    explicit NFSManager(QWidget *parent = 0);
    ~NFSManager();

private:
    Ui::NFSManager *ui;
};

#endif // NFSMANAGER_H
