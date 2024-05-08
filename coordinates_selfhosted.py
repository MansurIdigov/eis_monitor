#!/usr/bin/python
# -*- coding:utf-8 -*-

import RPi.GPIO as GPIO
import serial
from datetime import datetime
import requests
import time

URL = "http://82.194.143.119:80"
API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c'
headers = {'Authorization': f'Bearer {API_KEY}','Content-Type': 'application/json',
            'Accept': 'application/json'}

class SIM7600X_GPS:
    def __init__(self, serial_port='/dev/ttyS0', baud_rate=115200, power_key_pin=6):
        self.ser = serial.Serial(serial_port, baud_rate)
        self.ser.flushInput()
        self.power_key_pin = power_key_pin
        self.latitude = None
        self.longitude = None

    def send_command(self, command, expected_response, timeout=1):
        self.ser.write((command + '\r\n').encode())
        time.sleep(timeout)
        response = self.ser.read(self.ser.inWaiting()).decode().strip()
        if expected_response in response:
            return response

    def power_on(self):
        print('Starting Module')
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.power_key_pin, GPIO.OUT)
        GPIO.output(self.power_key_pin, GPIO.HIGH)
        time.sleep(2)
        GPIO.output(self.power_key_pin, GPIO.LOW)
        time.sleep(20)
        print('Module is ready')

    def get_gps_position(self):
        print('Getting GPS data...')
        self.send_command('AT+CGPS=1,1', 'OK')
        time.sleep(2)
        response = self.send_command('AT+CGPSINFO', '+CGPSINFO:')
        if response:
            gps_data = response.split(':')[1].strip()
            if gps_data == ',,,,,,':
                print('Module is not ready')
            else:
                self.latitude, self.longitude = self.parse_gps_data(gps_data)
                date_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                data = {'Zeit': date_time, 'Breitengrad': breitengrad, "Längengrad": laengengrad}
                response = requests.post(f"{URL}/koordinaten", data=json.dumps(data), headers=headers)
                print("Latitude:", self.latitude)
                print("Longitude:", self.longitude)
        else:
            print('Failed to get GPS data')

    def parse_gps_data(self, gps_data):
        lat_degrees = float(gps_data[0:2])
        lat_minutes = float(gps_data[2:11]) / 60
        lat_direction = -1 if gps_data[12] == 'S' else 1
        latitude = lat_direction * (lat_degrees + lat_minutes)

        long_degrees = float(gps_data[14:17])
        long_minutes = float(gps_data[17:26]) / 60
        long_direction = -1 if gps_data[27] == 'W' else 1
        longitude = long_direction * (long_degrees + long_minutes)

        return latitude, longitude

    def power_off(self):
        print('Turning off Module')
        GPIO.output(self.power_key_pin, GPIO.HIGH)
        time.sleep(3)
        GPIO.output(self.power_key_pin, GPIO.LOW)
        time.sleep(18)
        print('Module off')

if __name__ == "__main__":
    try:
        sim7600x_gps = SIM7600X_GPS()
        sim7600x_gps.power_on()
        while True:
            sim7600x_gps.get_gps_position()
            time.sleep(5)
    except Exception as e:
        print("Error:", str(e))
    finally:
        sim7600x_gps.power_off()
        sim7600x_gps.ser.close()
        GPIO.cleanup()


