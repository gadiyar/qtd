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

module browserapplication;


import qt.core.QBuffer;
import qt.core.QDir;
import qt.core.QLibraryInfo;
import qt.core.QSettings;
import qt.core.QTextStream;
import qt.core.QTranslator;
import qt.core.QUrl;
import qt.core.QPointer;

import qt.gui.QApplication;
import qt.gui.QIcon;
import qt.gui.QDesktopServices;
import qt.gui.QFileOpenEvent;
import qt.gui.QMessageBox;

import qt.network.QLocalServer;
import qt.network.QLocalSocket;
import qt.network.QNetworkProxy;
import qt.network.QSslSocket;

import QtWebKit.QWebSettings;

import qt.core.QDebug;

import bookmarks;
import browsermainwindow;
import cookiejar;
import downloadmanager;
import history;
import networkaccessmanager;
import tabwidget;
import webview;


class BrowserApplication : public QApplication
{
public:

	this(char[] args)
	{
		super(args);
		m_localServer = 0;
		QCoreApplication.setOrganizationName(QLatin1String("Trolltech"));
		QCoreApplication.setApplicationName(QLatin1String("demobrowser"));
		QCoreApplication.setApplicationVersion(QLatin1String("0.1"));
		version(Q_WS_QWS)
		{
			// Use a different server name for QWS so we can run an X11
			// browser and a QWS browser in parallel on the same machine for
			// debugging
			QString serverName = QCoreApplication.applicationName() + QLatin1String("_qws");
		} else {
			QString serverName = QCoreApplication.applicationName();
		}
		QLocalSocket socket;
		socket.connectToServer(serverName);
		if (socket.waitForConnected(500)) {
			auto stream = new QTextStream(&socket);
			QStringList args = QCoreApplication.arguments();
			if (args.count() > 1)
				stream << args.last();
			else
				stream << QString();
			stream.flush();
			socket.waitForBytesWritten();
			return;
		}

		version(Q_WS_MAC) {
			QApplication.setQuitOnLastWindowClosed(false);
		} else {
			QApplication.setQuitOnLastWindowClosed(true);
		}

		m_localServer = new QLocalServer(this);
		m_localServer.newConnection.connect(&this.newLocalSocketConnection);
		if (!m_localServer.listen(serverName)) {
			if (m_localServer.serverError() == QAbstractSocket.AddressInUseError
				&& QFile.exists(m_localServer.serverName())) {
				QFile.remove(m_localServer.serverName());
				m_localServer.listen(serverName);
			}
		}

		version(QT_NO_OPENSSL) {} else {
			if (!QSslSocket.supportsSsl()) {
				QMessageBox.information(0, "Demo Browser",
				"This system does not support OpenSSL. SSL websites will not be available.");
			}
		}

		QDesktopServices.setUrlHandler(QLatin1String("http"), this, "openUrl");
		QString localSysName = QLocale.system().name();

		installTranslator(QLatin1String("qt_") + localSysName);

		QSettings settings;
		settings.beginGroup(QLatin1String("sessions"));
		m_lastSession = settings.value(QLatin1String("lastSession")).toByteArray();
		settings.endGroup();

		version(Q_WS_MAC) {
			this.lastWindowClosed.connect(&this.lastWindowClosed);
		}

		QTimer.singleShot(0, this, SLOT(postLaunch()));
	}

	~this()
	{
		delete s_downloadManager;
		for (int i = 0; i < m_mainWindows.size(); ++i) {
			BrowserMainWindow window = m_mainWindows.at(i);
			delete window;
		}
		delete s_networkAccessManager;
		delete s_bookmarksManager;
	}

	static BrowserApplication instance()
	{
		return cast(BrowserApplication) QCoreApplication.instance();
	}

	void loadSettings()
	{
		QSettings settings;
		settings.beginGroup(QLatin1String("websettings"));

		QWebSettings defaultSettings = QWebSettings.globalSettings();
		QString standardFontFamily = defaultSettings.fontFamily(QWebSettings.StandardFont);
		int standardFontSize = defaultSettings.fontSize(QWebSettings.DefaultFontSize);
		QFont standardFont = QFont(standardFontFamily, standardFontSize);
		standardFont = qVariantValue!(QFont)(settings.value(QLatin1String("standardFont"), standardFont));
		defaultSettings.setFontFamily(QWebSettings.StandardFont, standardFont.family());
		defaultSettings.setFontSize(QWebSettings.DefaultFontSize, standardFont.pointSize());

		QString fixedFontFamily = defaultSettings.fontFamily(QWebSettings.FixedFont);
		int fixedFontSize = defaultSettings.fontSize(QWebSettings.DefaultFixedFontSize);
		QFont fixedFont = QFont(fixedFontFamily, fixedFontSize);
		fixedFont = qVariantValue!(QFont)(settings.value(QLatin1String("fixedFont"), fixedFont));
		defaultSettings.setFontFamily(QWebSettings.FixedFont, fixedFont.family());
		defaultSettings.setFontSize(QWebSettings.DefaultFixedFontSize, fixedFont.pointSize());

		defaultSettings.setAttribute(QWebSettings.JavascriptEnabled, settings.value(QLatin1String("enableJavascript"), true).toBool());
		defaultSettings.setAttribute(QWebSettings.PluginsEnabled, settings.value(QLatin1String("enablePlugins"), true).toBool());

		QUrl url = settings.value(QLatin1String("userStyleSheet")).toUrl();
		defaultSettings.setUserStyleSheetUrl(url);

		settings.endGroup();
	}

	bool isTheOnlyBrowser()
	{
		return (m_localServer != 0);
	}

	BrowserMainWindow mainWindow()
	{
		clean();
		if (m_mainWindows.isEmpty())
			newMainWindow();
		return m_mainWindows[0];
	}

	BrowserMainWindow[] mainWindows()
	{
		clean();
		BrowserMainWindow[] list;
		for (int i = 0; i < m_mainWindows.count(); ++i)
			list ~= m_mainWindows.at(i);
		return list;
	}

	QIcon icon(QUrl url)
	{
		QIcon icon = QWebSettings.iconForUrl(url);
		if (!icon.isNull())
			return icon.pixmap(16, 16);
		if (m_defaultIcon.isNull())
			m_defaultIcon = QIcon(QLatin1String(":defaulticon.png"));
		return m_defaultIcon.pixmap(16, 16);
	}

	void saveSession()
	{
		QWebSettings globalSettings = QWebSettings.globalSettings();
		if (globalSettings.testAttribute(QWebSettings.PrivateBrowsingEnabled))
			return;

		clean();

		QSettings settings;
		settings.beginGroup(QLatin1String("sessions"));

		QByteArray data;
		auto buffer = new QBuffer(&data);
		auto stream = new QDataStream(&buffer);
		buffer.open(QIODevice.ReadWrite);

		stream << m_mainWindows.count();
		for (int i = 0; i < m_mainWindows.count(); ++i)
			stream << m_mainWindows.at(i).saveState();
		settings.setValue(QLatin1String("lastSession"), data);
		settings.endGroup();
	}

	bool canRestoreSession()
	{
		return !m_lastSession.isEmpty();
	}

	static HistoryManager historyManager()
	{
		if (!s_historyManager) {
			s_historyManager = new HistoryManager();
			QWebHistoryInterface.setDefaultInterface(s_historyManager);
		}
		return s_historyManager;
	}

	static CookieJar cookieJar()
	{
		return cast(CookieJar) networkAccessManager().cookieJar();
	}
	
	static DownloadManager downloadManager()
	{
		if (!s_downloadManager) {
			s_downloadManager = new DownloadManager();
		}
		return s_downloadManager;
	}

	static NetworkAccessManager networkAccessManager()
	{
		if (!s_networkAccessManager) {
			s_networkAccessManager = new NetworkAccessManager();
			s_networkAccessManager.setCookieJar(new CookieJar);
		}
		return s_networkAccessManager;
	}


	static BookmarksManager bookmarksManager()
	{
		if (!s_bookmarksManager) {
			s_bookmarksManager = new BookmarksManager;
		}
		return s_bookmarksManager;
	}


version(Q_WS_MAC)
{
	bool event(QEvent event)
	{
		switch (event.type()) {
			case QEvent.ApplicationActivate: {
				clean();
				if (!m_mainWindows.isEmpty()) {
					BrowserMainWindow mw = mainWindow();
					if (mw && !mw.isMinimized()) {
						mainWindow().show();
					}
					return true;
				}
			}
			case QEvent.FileOpen:
				if (!m_mainWindows.isEmpty()) {
					mainWindow().loadPage(cast(QFileOpenEvent) event.file());
					return true;
				}
			default:
				break;
		}
		return QApplication.event(event);
	}
}

public:

	BrowserMainWindow newMainWindow()
	{
		BrowserMainWindow browser = new BrowserMainWindow();
		m_mainWindows.prepend(browser);
		browser.show();
		return browser;
	}

	void restoreLastSession()
	{
		QByteArray[] windows;
		auto buffer = new QBuffer(&m_lastSession);
		auto stream = new QDataStream(&buffer);
		buffer.open(QIODevice.ReadOnly);
		int windowCount;
		stream >> windowCount;
		for (int i = 0; i < windowCount; ++i) {
			QByteArray windowState;
			stream >> windowState;
			windows ~= windowState;
		}
		for (int i = 0; i < windows.count(); ++i) {
			BrowserMainWindow newWindow = 0;
			if (m_mainWindows.count() == 1 && mainWindow().tabWidget().count() == 1
				&& mainWindow().currentTab().url() == QUrl()) {
				newWindow = mainWindow();
			} else {
				newWindow = newMainWindow();
			}
			newWindow.restoreState(windows.at(i));
		}
	}


version(Q_WS_MAC)
{
	import qt.gui.QMessageBox;
	
	void quitBrowser()
	{
		clean();
		int tabCount = 0;
		for (int i = 0; i < m_mainWindows.count(); ++i) {
			tabCount =+ m_mainWindows.at(i).tabWidget().count();
		}

		if (tabCount > 1) {
			int ret = QMessageBox.warning(mainWindow(), QString(),
			tr("There are %1 windows and %2 tabs open\n"
				"Do you want to quit anyway?").arg(m_mainWindows.count()).arg(tabCount),
			QMessageBox.Yes | QMessageBox.No,
			QMessageBox.No);
			if (ret == QMessageBox.No)
				return;
		}

		exit(0);
	}
	
	void lastWindowClosed()
	{
		clean();
		BrowserMainWindow mw = new BrowserMainWindow;
		mw.slotHome();
		m_mainWindows.prepend(mw);
	}
}


private:

	/*!
	Any actions that can be delayed until the window is visible
	*/
	void postLaunch()
	{
		QString directory = QDesktopServices.storageLocation(QDesktopServices.DataLocation);
		if (directory.isEmpty())
			directory = QDir.homePath() ~ QLatin1String("/.") ~ QCoreApplication.applicationName();
		QWebSettings.setIconDatabasePath(directory);

		setWindowIcon(QIcon(QLatin1String(":browser.svg")));

		loadSettings();

		// newMainWindow() needs to be called in main() for this to happen
		if (m_mainWindows.count() > 0) {
			QStringList args = QCoreApplication.arguments();
			if (args.count() > 1)
				mainWindow().loadPage(args.last());
			else
				mainWindow().slotHome();
		}
		BrowserApplication.historyManager();
	}

	void openUrl( QUrl url)
	{
		mainWindow().loadPage(url.toString());
	}

	void newLocalSocketConnection()
	{
		QLocalSocket socket = m_localServer.nextPendingConnection();
		if (!socket)
			return;
		socket.waitForReadyRead(1000);
		QTextStream stream(socket);
		QString url;
		stream >> url;
		if (!url.isEmpty()) {
			QSettings settings;
			settings.beginGroup(QLatin1String("general"));
			int openLinksIn = settings.value(QLatin1String("openLinksIn"), 0).toInt();
			settings.endGroup();
			if (openLinksIn == 1)
				newMainWindow();
			else
				mainWindow().tabWidget().newTab();
			openUrl(url);
		}
		delete socket;
		mainWindow().raise();
		mainWindow().activateWindow();
	}

private:

	void clean()
	{
		// cleanup any deleted main windows first
		for (int i = m_mainWindows.count() - 1; i >= 0; --i)
			if (m_mainWindows.at(i).isNull())
				m_mainWindows.removeAt(i);
	}

	void installTranslator(QString name)
	{
		QTranslator translator = new QTranslator(this);
		translator.load(name, QLibraryInfo.location(QLibraryInfo.TranslationsPath));
		QApplication.installTranslator(translator);
	}

	static HistoryManager s_historyManager;
	static DownloadManager s_downloadManager;
	static NetworkAccessManager s_networkAccessManager;
	static BookmarksManager s_bookmarksManager;
	
	QPointer!(BrowserMainWindow)[] m_mainWindows;
	QLocalServer m_localServer;
	QByteArray m_lastSession;
	QIcon m_defaultIcon;
}
