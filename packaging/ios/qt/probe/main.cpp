#include <QApplication>
#include <QBuffer>
#include <QDomDocument>
#include <QImage>
#include <QNetworkRequest>
#include <QOpenGLWidget>
#include <QSqlDatabase>
#include <QSvgRenderer>
#include <QTextCodec>
#include <QtConcurrentRun>
#include <quazip/quazip.h>

int main(int argc, char** argv)
{
    QApplication application(argc, argv);
    const QByteArray svg("<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1'/>");
    QSvgRenderer renderer(svg);
    QDomDocument document;
    document.setContent(svg);
    const QImage image(1, 1, QImage::Format_ARGB32_Premultiplied);
    const QNetworkRequest request;
    const auto database = QSqlDatabase::addDatabase("QSQLITE");
    const auto codec = QTextCodec::codecForName("UTF-8");
    const auto future = QtConcurrent::run([] { return 6; });
    QuaZip archive;
    QOpenGLWidget widget;
    return renderer.isValid() && !document.isNull() && !image.isNull()
            && request.url().isEmpty() && database.isValid() && codec != nullptr
            && future.result() == 6 && archive.getMode() == QuaZip::mdNotOpen
            && widget.isEnabled()
        ? 0
        : 1;
}
