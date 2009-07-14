/****************************************************************************
**
** Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies).
** Contact: Qt Software Information (qt-info@nokia.com)
**
** This file is part of the example classes of the Qt Toolkit.
**
** Commercial Usage
** Licensees holding valid Qt Commercial licenses may use this file in
** accordance with the Qt Commercial License Agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Nokia.
**
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License versions 2.0 or 3.0 as published by the Free
** Software Foundation and appearing in the file LICENSE.GPL included in
** the packaging of this file.  Please review the following information
** to ensure GNU General Public Licensing requirements will be met:
** http://www.fsf.org/licensing/licenses/info/GPLv2.html and
** http://www.gnu.org/copyleft/gpl.html.  In addition, as a special
** exception, Nokia gives you certain additional rights. These rights
** are described in the Nokia Qt GPL Exception version 1.3, included in
** the file GPL_EXCEPTION.txt in this package.
**
** Qt for Windows(R) Licensees
** As a special exception, Nokia, as the sole copyright holder for Qt
** Designer, grants users of the Qt/Eclipse Integration plug-in the
** right for the Qt/Eclipse Integration to link to functionality
** provided by Qt Designer and its related libraries.
**
** If you are unsure which license is appropriate for your use, please
** contact the sales department at qt-sales@nokia.com.
**
****************************************************************************/

import std.math;
import std.conv;

import qt.core.QPoint;
import qt.gui.QMouseEvent;
import qt.opengl.QGLWidget;
import qt.gui.QColor;
import qt.core.QSize;
import qt.opengl.gl;
import qt.opengl.glu;

class GLWidget : QGLWidget
{
//    Q_OBJECT

    public:
        this(QWidget parent = null)
        {
            super(parent);
            object = 0;
            xRot = 0;
            yRot = 0;
            zRot = 0;

            trolltechGreen = QColor.fromCmykF(0.40, 0.0, 1.0, 0.0);
            trolltechPurple = QColor.fromCmykF(0.39, 0.39, 0.0, 0.0);
        }

        ~this()
        {
            makeCurrent();
            glDeleteLists(object, 1);
        }

        QSize minimumSizeHint()
        {
            return QSize(50, 50);
        }

        QSize sizeHint()
        {
            return QSize(400, 400);
        }


    public: // slots:
        void setXRotation(int angle)
        {
            normalizeAngle(&angle);
            if (angle != xRot) {
                xRot = angle;
                xRotationChanged.emit(angle);
                updateGL();
            }
        }

        void setYRotation(int angle)
        {
            normalizeAngle(&angle);
            if (angle != yRot) {
                yRot = angle;
                yRotationChanged.emit(angle);
                updateGL();
            }
        }

        void setZRotation(int angle)
        {
            normalizeAngle(&angle);
            if (angle != zRot) {
                zRot = angle;
                zRotationChanged.emit(angle);
                updateGL();
            }
        }

        mixin Signal!("xRotationChanged", int);
        mixin Signal!("yRotationChanged", int);
        mixin Signal!("zRotationChanged", int);


    protected:
        void initializeGL()
        {
            qglClearColor(trolltechPurple.darker());
            object = makeObject();
            glShadeModel(GL_FLAT);
            glEnable(GL_DEPTH_TEST);
            glEnable(GL_CULL_FACE);
        }

        void paintGL()
        {
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glLoadIdentity();
            glTranslated(0.0, 0.0, -10.0);
            glRotated(xRot / 16.0, 1.0, 0.0, 0.0);
            glRotated(yRot / 16.0, 0.0, 1.0, 0.0);
            glRotated(zRot / 16.0, 0.0, 0.0, 1.0);
            glCallList(object);
        }

        void resizeGL(int width, int height)
        {
            int side = qMin(width, height);
            glViewport((width - side) / 2, (height - side) / 2, side, side);

            glMatrixMode(GL_PROJECTION);
            glLoadIdentity();
            glOrtho(-0.5, +0.5, +0.5, -0.5, 4.0, 15.0);
            glMatrixMode(GL_MODELVIEW);
        }

        void mousePressEvent(QMouseEvent event)
        {
            lastPos = QPoint(event.pos.x, event.pos.y);
        }

        void mouseMoveEvent(QMouseEvent event)
        {
            int dx = event.x - lastPos.x;
            int dy = event.y - lastPos.y;

            if (event.buttons() & Qt.LeftButton) {
                setXRotation(xRot + 8 * dy);
                setYRotation(yRot + 8 * dx);
            } else if (event.buttons() & Qt.RightButton) {
                setXRotation(xRot + 8 * dy);
                setZRotation(zRot + 8 * dx);
            }
            lastPos = QPoint(event.pos.x, event.pos.y);
        }
    private:
        GLuint makeObject()
        {
            GLuint list = glGenLists(1);
            glNewList(list, GL_COMPILE);

            glBegin(GL_QUADS);

            GLdouble x1 = +0.06;
            GLdouble y1 = -0.14;
            GLdouble x2 = +0.14;
            GLdouble y2 = -0.06;
            GLdouble x3 = +0.08;
            GLdouble y3 = +0.00;
            GLdouble x4 = +0.30;
            GLdouble y4 = +0.22;

            quad(x1, y1, x2, y2, y2, x2, y1, x1);
            quad(x3, y3, x4, y4, y4, x4, y3, x3);

            extrude(x1, y1, x2, y2);
            extrude(x2, y2, y2, x2);
            extrude(y2, x2, y1, x1);
            extrude(y1, x1, x1, y1);
            extrude(x3, y3, x4, y4);
            extrude(x4, y4, y4, x4);
            extrude(y4, x4, y3, x3);

            const double Pi = 3.14159265358979323846;
            const int NumSectors = 200;

            for (int i = 0; i < NumSectors; ++i) {
                double angle1 = (i * 2 * Pi) / NumSectors;
                GLdouble x5 = 0.30 * sin(angle1);
                GLdouble y5 = 0.30 * cos(angle1);
                GLdouble x6 = 0.20 * sin(angle1);
                GLdouble y6 = 0.20 * cos(angle1);

                double angle2 = ((i + 1) * 2 * Pi) / NumSectors;
                GLdouble x7 = 0.20 * sin(angle2);
                GLdouble y7 = 0.20 * cos(angle2);
                GLdouble x8 = 0.30 * sin(angle2);
                GLdouble y8 = 0.30 * cos(angle2);

                quad(x5, y5, x6, y6, x7, y7, x8, y8);

                extrude(x6, y6, x7, y7);
                extrude(x8, y8, x5, y5);
            }

            glEnd();

            glEndList();
            return list;
        }

        void quad(GLdouble x1, GLdouble y1, GLdouble x2, GLdouble y2,
                   GLdouble x3, GLdouble y3, GLdouble x4, GLdouble y4)
        {
            qglColor(trolltechGreen);

            glVertex3d(x1, y1, -0.05);
            glVertex3d(x2, y2, -0.05);
            glVertex3d(x3, y3, -0.05);
            glVertex3d(x4, y4, -0.05);

            glVertex3d(x4, y4, +0.05);
            glVertex3d(x3, y3, +0.05);
            glVertex3d(x2, y2, +0.05);
            glVertex3d(x1, y1, +0.05);
        }

        void extrude(GLdouble x1, GLdouble y1, GLdouble x2, GLdouble y2)
        {
            qglColor(trolltechGreen.darker(to!(int)(rndtol(250 + (100 * x1)))));

            glVertex3d(x1, y1, +0.05);
            glVertex3d(x2, y2, +0.05);
            glVertex3d(x2, y2, -0.05);
            glVertex3d(x1, y1, -0.05);
        }

        void normalizeAngle(int *angle)
        {
            while (*angle < 0)
                *angle += 360 * 16;
            while (*angle > 360 * 16)
                *angle -= 360 * 16;
        }

        GLuint object;
        int xRot;
        int yRot;
        int zRot;
        QPoint lastPos;
        QColor trolltechGreen;
        QColor trolltechPurple;
}