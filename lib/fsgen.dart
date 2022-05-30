import 'package:dartdoc/dartdoc.dart';
import 'package:analyzer/dart/element/element.dart';
// import 'package:analyzer/src/dart/element/element.dart';

class Dependency {
  final Uri libraryUri;
  final String libraryName;
  final String libraryVersion;

  Dependency(this.libraryUri, this.libraryName, this.libraryVersion);

  @override
  bool operator ==(Object other) =>
      other is Dependency &&
      (libraryUri == other.libraryUri &&
          libraryName == other.libraryName &&
          libraryVersion == other.libraryVersion);

  @override
  int get hashCode => Object.hash(libraryUri, libraryName, libraryVersion);

  @override
  String toString() {
    return 'Dependency{libraryUri: $libraryUri, libraryName: $libraryName, libraryVersion: $libraryVersion}';
  }
}

class RenderParamsResult {
  final String rendered;
  final int namedIndex;
  RenderParamsResult(this.rendered, [this.namedIndex = -1]);
}

class FsGenerator implements Generator {
  Dependency? dependency(
      LibraryElement? elementType, PackageGraph packageGraph) {
    if (elementType == null) return null;
    final metadata = packageGraph.packageMetaProvider
        .fromElement(elementType, packageGraph.config.sdkDir);
    return Dependency(elementType.source.uri, metadata!.name, metadata.version);
  }

  String isConst(bool isConst) {
    return isConst ? '[<IsConst>] ' : '';
  }

  String paramAttributes(bool isConst, int namedIndex) {
    final a = isConst ? "[<IsConst>] " : "";
    final b = namedIndex >= 0 ? '[<NamedParams${namedIndex != 0 ? '(fromIndex=$namedIndex)' : ''}>] ' : '';
    return a + b;
  }

  RenderParamsResult renderParams(List<Parameter> parameters) {
    String renderParam(ParameterElement e) {
      return '${e.isOptional ? "?" : ""}${e.name} : ${e is TypeParameterElementType ? "'":''}${e.type.element?.name ?? e.type.alias?.element.name ?? e.type.getDisplayString(withNullability: true)}';
    }

    final parameterEls = parameters.map((e) => e.element!).toList();
    // If there are optional positional params there should be no named params
    if (parameterEls.any((element) => element.isOptionalPositional)) {
      final required = parameterEls.where((e) => e.isRequiredPositional).map(renderParam);
      final optional = parameterEls.where((e) => e.isOptionalPositional).map(renderParam);
      return RenderParamsResult(required.followedBy(optional).join(", "));
    }
    else {
      final positional = parameterEls.where((e) => e.isPositional).map(renderParam).toList();
      final namedRequired = parameterEls.where((e) => e.isRequiredNamed).map(renderParam).toList();
      final namedOptional = parameterEls.where((e) => e.isOptionalNamed).map(renderParam).toList();
      final namedIndex = namedRequired.isNotEmpty || namedOptional.isNotEmpty ? positional.length : -1;
      return RenderParamsResult(positional.followedBy(namedRequired).followedBy(namedOptional).join(", "), namedIndex);
    }
  }

  String renderGenericArgs(Iterable<Element> genericParams) => genericParams
          .isEmpty
      ? ''
      : '<${genericParams.map((e) => "${e.kind == ElementKind.TYPE_PARAMETER ? "'":''}${e.name}").reduce((value, element) => '$value, $element')}>';

  @override
  Future<void> generate(PackageGraph packageGraph, FileWriter writer) async {
    // print("Default: ${packageGraph.defaultPackageName}");

    final packages = [packageGraph.defaultPackage]; //packageGraph.packages
    final moduleName = "Flutter.Material";
    final modulePath = "package:flutter/material.dart";
    final fileFilter = "src/material";
    final superClassFilter = "src/material";
    final printAtEnd = "  interface Widget";

    for (final package in packages) {

      var buffer = StringBuffer();
      buffer.writeln('module rec $moduleName');
      buffer.writeln();
      buffer.writeln('let [<Literal>] private PATH = "$modulePath"');
      buffer.writeln();

      for (final lib in package.libraries) {
        if (!lib.isPublic || !lib.sourceFileName.contains(fileFilter) ) continue;

        // final currentLibUri = lib.element.source.uri;
        // final dependencies = Set<Dependency>.identity();
        // for (final libEl in lib.element.importedLibraries) {
        //   if (libEl.isPrivate) continue;
        //   final dep = dependency(libEl, packageGraph);
        //   if (dep != null && dep.libraryUri != currentLibUri) {
        //     dependencies.add(dep);
        //   }
        // }

        for (final clazz in lib.classes) {
          if (!clazz.isCanonical) continue;
          
          final superClazz = (clazz.supertype?.isPublic ?? false) ? clazz.supertype : null;
          if (superClazz == null || superClazz.name != superClassFilter) continue;

          final genericParams = clazz.typeParameters;
          final renderedClassGenerics = renderGenericArgs(genericParams.map((e) => e.element!));
          var headerPrinted = false;
          var moreThanHeader = false;

          buffer.writeln('/// https://api.flutter.dev/flutter/material/${clazz.name}-class.html');
          buffer.writeln('[<ImportMember("PATH")>');

          var defCons = clazz.unnamedConstructor;
          if (defCons != null) {
            headerPrinted = true;
            final renderedParams = renderParams(defCons.parameters);
            buffer.writeln(
                'type ${clazz.name}$renderedClassGenerics ${paramAttributes(defCons.isConst, renderedParams.namedIndex)}(${renderedParams.rendered}) =');
          }

          moreThanHeader = true;
          // if (superClazz != null) {
          //   moreThanHeader = true;
          //   final superGenerics = renderGenericArgs(
          //       superClazz?.typeArguments.where((e) => e.type.element != null)
          //           .map((e) => e.type.element!) ?? []);
          //   final args = ((defaultConstructor?.element as ConstructorElementImpl?)?.superConstructor?.parameters.length ?? 0);
          //   buffer.writeln('  inherit ${superClazz.name}$superGenerics(${args == 0 ? '' : List.generate(args, (_) => 'nativeOnly')
          //       .reduce((value, element) => '$value, $element')})');
          // }

          if (!headerPrinted) {
            headerPrinted = true;
            buffer.writeln('type ${clazz.name}$renderedClassGenerics =');
          }

          final namedConstructors = clazz.constructors.where((element) => !element.isUnnamedConstructor && element.isCanonical);
          for (final cons in namedConstructors) {
            final renderedParams = renderParams(cons.parameters);
            moreThanHeader = true;
            final treated = cons.name.substring(clazz.name.length + 1);
            buffer.writeln(
                '  ${paramAttributes(cons.isConst, renderedParams.namedIndex)}static member $treated(${renderedParams.rendered}): ${clazz.name}$renderedClassGenerics = nativeOnly'
            );
          }

          if (printAtEnd != null) {
            buffer.writeln('  interface Widget');

          } else if (!moreThanHeader) {
            buffer.writeln('  class end');
          }
          buffer.writeln();
        }

        // print('$lib dependencies:');
        // for (final d in dependencies) {
        //   print(d);
        // }

      } // for (final lib in package.libraries) {

      writer.write('$moduleName.fs', buffer.toString());
    }
  }
}
