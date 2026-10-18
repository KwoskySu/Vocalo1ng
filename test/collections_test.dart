import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/collections.dart';
import 'package:vocashelf/models/music.dart';
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('likes, folders and comment bookmarks persist independently',()async{
    SharedPreferences.setMockInitialValues({});
    final store=Collections();const track=MusicTrack(id:'123',title:'Title',artist:'Artist');
    await store.toggleLike(track);expect(store.folders.values.every((f)=>f.isEmpty),true);
    await store.createFolder('夜行');await store.setFolders(track,{'夜行'});
    await store.toggleComment('123:9',{'id':'9','text':'review','likes':32,'source':'https://music.163.com/song?id=123'});
    final restored=Collections();await restored.load();
    expect(restored.liked,{'123'});expect(restored.folders['夜行'],{'123'});expect(restored.comments['123:9']!['likes'],32);
    await restored.toggleLike(track);expect(restored.folders['夜行'],{'123'});
    await restored.setFolders(track,{});expect(restored.liked,isEmpty);expect(restored.tracks['123']!.title,'Title');
    expect(()=>restored.createFolder('夜行'),throwsArgumentError);
  });
}
