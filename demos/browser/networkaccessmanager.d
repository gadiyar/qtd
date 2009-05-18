/****************************************************************************
**
** Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies).
** Contact: Qt Software Information (qt-info@nokia.com)
**
** This file is part of the demonstration applications of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial Usage
** Licensees holding valid Qt Commercial licenses may use this file in
** accordance with the Qt Commercial License Agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Nokia.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU Lesser General Public License version 2.1 requirements
** will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Nokia gives you certain
** additional rights. These rights are described in the Nokia Qt LGPL
** Exception version 1.0, included in the file LGPL_EXCEPTION.txt in this
** package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3.0 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU General Public License version 3.0 requirements will be
** met: http://www.gnu.org/copyleft/gpl.html.
**
** If you are unsure which license is appropriate for your use, please
** contact the sales department at qt-sales@nokia.com.
** $QT_END_LICENSE$
**
****************************************************************************/

module networkaccessmanager;


import QtNetwork.QNetworkAccessManager;

import browserapplication;
import browsermainwindow;
import ui_passworddialog;
import ui_proxy;

import QtCore.QSettings;

import QtGui.QDesktopServices;
import QtGui.QDialog;
import QtGui.QMessageBox;
import QtGui.QStyle;
import QtGui.QTextDocument;

import QtNetwork.QAuthenticator;
import QtNetwork.QNetworkDiskCache;
import QtNetwork.QNetworkProxy;
import QtNetwork.QNetworkReply;
import QtNetwork.QSslError;


class NetworkAccessManager : public QNetworkAccessManager
{
    Q_OBJECT

public:
    this(QObject *parent = null)
{
	super(parent);
	
    connect(this, SIGNAL(authenticationRequired(QNetworkReply*, QAuthenticator*)),
            SLOT(authenticationRequired(QNetworkReply*,QAuthenticator*)));
    connect(this, SIGNAL(proxyAuthenticationRequired(const QNetworkProxy&, QAuthenticator*)),
            SLOT(proxyAuthenticationRequired(const QNetworkProxy&, QAuthenticator*)));
version(QT_NO_OPENSSL) {
    connect(this, SIGNAL(sslErrors(QNetworkReply*, const QList<QSslError>&)),
            SLOT(sslErrors(QNetworkReply*, const QList<QSslError>&)));
}
    loadSettings();

    QNetworkDiskCache *diskCache = new QNetworkDiskCache(this);
    QString location = QDesktopServices::storageLocation(QDesktopServices::CacheLocation);
    diskCache.setCacheDirectory(location);
    setCache(diskCache);
}

private:
    QList<QString> sslTrustedHostList;

public slots:
    void loadSettings()
{
    QSettings settings;
    settings.beginGroup(QLatin1String("proxy"));
    QNetworkProxy proxy;
    if (settings.value(QLatin1String("enabled"), false).toBool()) {
        if (settings.value(QLatin1String("type"), 0).toInt() == 0)
            proxy = QNetworkProxy::Socks5Proxy;
        else
            proxy = QNetworkProxy::HttpProxy;
        proxy.setHostName(settings.value(QLatin1String("hostName")).toString());
        proxy.setPort(settings.value(QLatin1String("port"), 1080).toInt());
        proxy.setUser(settings.value(QLatin1String("userName")).toString());
        proxy.setPassword(settings.value(QLatin1String("password")).toString());
    }
    setProxy(proxy);
}


private slots:
    void authenticationRequired(QNetworkReply *reply, QAuthenticator *auth)
{
    BrowserMainWindow *mainWindow = BrowserApplication::instance().mainWindow();

    QDialog dialog(mainWindow);
    dialog.setWindowFlags(Qt::Sheet);

    Ui::PasswordDialog passwordDialog;
    passwordDialog.setupUi(&dialog);

    passwordDialog.iconLabel.setText(QString());
    passwordDialog.iconLabel.setPixmap(mainWindow.style().standardIcon(QStyle::SP_MessageBoxQuestion, 0, mainWindow).pixmap(32, 32));

    QString introMessage = tr("<qt>Enter username and password for \"%1\" at %2</qt>");
    introMessage = introMessage.arg(Qt::escape(reply.url().toString())).arg(Qt::escape(reply.url().toString()));
    passwordDialog.introLabel.setText(introMessage);
    passwordDialog.introLabel.setWordWrap(true);

    if (dialog.exec() == QDialog::Accepted) {
        auth.setUser(passwordDialog.userNameLineEdit.text());
        auth.setPassword(passwordDialog.passwordLineEdit.text());
    }
}

void proxyAuthenticationRequired(const QNetworkProxy &proxy, QAuthenticator *auth)
{
    BrowserMainWindow *mainWindow = BrowserApplication::instance().mainWindow();

    QDialog dialog(mainWindow);
    dialog.setWindowFlags(Qt::Sheet);

    Ui::ProxyDialog proxyDialog;
    proxyDialog.setupUi(&dialog);

    proxyDialog.iconLabel.setText(QString());
    proxyDialog.iconLabel.setPixmap(mainWindow.style().standardIcon(QStyle::SP_MessageBoxQuestion, 0, mainWindow).pixmap(32, 32));

    QString introMessage = tr("<qt>Connect to proxy \"%1\" using:</qt>");
    introMessage = introMessage.arg(Qt::escape(proxy.hostName()));
    proxyDialog.introLabel.setText(introMessage);
    proxyDialog.introLabel.setWordWrap(true);

    if (dialog.exec() == QDialog::Accepted) {
        auth.setUser(proxyDialog.userNameLineEdit.text());
        auth.setPassword(proxyDialog.passwordLineEdit.text());
    }
}

version(QT_NO_OPENSSL) {
void sslErrors(QNetworkReply *reply, const QList<QSslError> &error)
{
    // check if SSL certificate has been trusted already
    QString replyHost = reply.url().host() + ":" + reply.url().port();
    if(! sslTrustedHostList.contains(replyHost)) {
        BrowserMainWindow *mainWindow = BrowserApplication::instance().mainWindow();

        QStringList errorStrings;
        for (int i = 0; i < error.count(); ++i)
            errorStrings += error.at(i).errorString();
        QString errors = errorStrings.join(QLatin1String("\n"));
        int ret = QMessageBox::warning(mainWindow, QCoreApplication::applicationName(),
                tr("SSL Errors:\n\n%1\n\n%2\n\n"
                        "Do you want to ignore these errors for this host?").arg(reply.url().toString()).arg(errors),
                        QMessageBox::Yes | QMessageBox::No,
                        QMessageBox::No);
        if (ret == QMessageBox::Yes) {
            reply.ignoreSslErrors();
            sslTrustedHostList.append(replyHost);
        }
    }
}
}

}