import 'dart:convert';
import 'dart:typed_data';
Uint8List galleryPng()=>base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQKAj4DwADdAHgD6AZwQAAAABJRU5ErkJggg==');
Map<String,dynamic> galleryPhoto(int index)=>{'id':'00000000-0000-4000-8000-${index.toString().padLeft(12,'0')}','previewVersion':'v1','state':'stored','farm':index.isEven?'나상 가명A종묘':'하상 농가 B','crop':'토마토','variety':'루비','date':'2026-11-0${index%5+1}','region':index.isEven?'전남 담양':'강원 춘천','note':'생육 양호','notification':'sent','email':'member@example.com'};
