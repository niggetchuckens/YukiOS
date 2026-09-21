/* YukiOS Calamares Slideshow */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 6000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1b26"
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Welcome to YukiOS"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#7aa2f7"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "A fast, modular and streamlined Arch Linux distribution"
                    font.pixelSize: 15
                    color: "#a9b1d6"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1b26"
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Optimized Performance"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#7aa2f7"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Equipped with high-performance kernels and package repositories"
                    font.pixelSize: 15
                    color: "#a9b1d6"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1b26"
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Ready for Work & Play"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#7aa2f7"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Pre-configured development tools, AUR support, and desktop environments"
                    font.pixelSize: 15
                    color: "#a9b1d6"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
