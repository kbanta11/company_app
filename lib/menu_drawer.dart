import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/user_model.dart';
import 'services/auth_services.dart';
import 'providers/auth_providers.dart';
import 'join_group_page.dart';
import 'main.dart';
import 'inbox_page.dart';
import 'signin_page.dart';

class MenuDrawer extends ConsumerWidget {
  String? page;

  MenuDrawer(this.page);

  @override
  build(BuildContext context, ScopedReader watch) {
    AppUser? currentUser = watch(appUserProvider).data?.value;
    return Drawer(
        child: ListView(
            children: [
              ListTile(
                  title: const Text('Home'),
                  onTap: () {
                    if(page != 'home-page') {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                    }
                  }
              ),
              ListTile(
                  title: const Text('Join Another Group'),
                  onTap: () {
                    if(page != 'join-group') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => JoinGroupPage()));
                    }
                  }
              ),
              ListTile(
                  title: const Text('Messages'),
                  trailing: (currentUser?.unreadDirectMessages ?? 0) > 0 ? Container(
                      height: 20,
                      width: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Center(
                        child: Text('${currentUser?.unreadDirectMessages}', style: const TextStyle(color: Colors.white)),
                      )
                  ) : SizedBox(),
                  onTap: () {
                    if(page != 'inbox-page') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => InboxPage()));
                    }
                  }
              ),
              ListTile(
                  title: const Text('Logout'),
                  onTap: () async {
                    await AuthService().logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignInPage()));
                  }
              ),
              /*
            ListTile(
              title: const Text('Seed Group Data'),
              onTap: () async {
                await DatabaseServices().seedGroupData();
              }
            )
             */
            ]
        )
    );
  }
}

class DrawerButton extends StatelessWidget {
  AppUser? currentUser;

  DrawerButton(this.currentUser);

  @override
  build(BuildContext context) {
    return Stack(
        children: [
          Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              )
          ),
          Positioned(
            top: 7.5,
            right: 12,
            child: (currentUser?.unreadDirectMessages ?? 0) > 0 ? Container(
              height: 15,
              width: 15,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Center(child: Text('${currentUser?.unreadDirectMessages}', style: const TextStyle(color: Colors.white))),
            ) : Container(),
          )
        ]
    );
  }
}