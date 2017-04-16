#include <Arduino.h>

#include <ESP8266WiFi.h>
#include <ESP8266WiFiMulti.h>
#include <ESP8266HTTPClient.h>

#include "rboot-api.h"
#include "config.h"

void setup() {
    pinMode(2, OUTPUT);

    Serial.begin(115200);
    Serial.println("");


    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }

    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());

    HTTPClient http;
    http.begin(url);

    int httpCode = http.GET();
    if(httpCode > 0) {
        // HTTP header has been send and Server response header has been handled
        Serial.printf("Got: %d\n\r", httpCode);
        uint8_t buffer[1024];

        int target = (rboot_get_current_rom() + 1) % 4;

        rboot_config config = rboot_get_config();
        int start_address = config.roms[target];
        rboot_write_status status = rboot_write_init(start_address);

        int size = 0;
        WiFiClient * stream = http.getStreamPtr();
        Serial.print("Flashing [");
        while(http.connected()) {
            int bytes_read = stream->readBytes(buffer, 1024);
            digitalWrite(2, HIGH);
            rboot_write_flash(&status, buffer, bytes_read);
            Serial.print("=");
            digitalWrite(2, LOW);
            size += bytes_read;
        }

        rboot_write_end(&status);
        rboot_set_current_rom(target);
        Serial.println("]");
        Serial.printf("Flashed %d bytes\n\r", size);
    }
    else {
         Serial.printf("Got %d: %s\n\r", httpCode, http.errorToString(httpCode).c_str());
    }

    Serial.println("Http done");

    ESP.restart();
}

void loop() {

}
