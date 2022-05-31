import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:dartdoc/dartdoc.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';

const keywords = ['begin', 'end', 'of', 'to', 'delegate', 'exception', 'type', 'inherit', 'interface', 'let', 'done',
  'lazy', 'open', 'global', 'process', 'checked', 'fixed', 'mixin', 'override', 'public', 'private'];

const moduleName = "material";
const packageFilter = "flutter";
final libraryFilter = "flutter/lib/$moduleName.dart";
final defininingLibraryFilter = "flutter/lib/src/$moduleName";
final modulePath = "package:flutter/$moduleName.dart";
final docUrl = 'https://api.flutter.dev/flutter/$moduleName/';
final fsharpModuleName = "Flutter.${firstToUpper(moduleName)}";

// const packageFilter = "vector_math";
// final libraryFilter = "lib/vector_math.dart"; //"lib/ui/ui.dart";
// final defininingLibraryFilter = "";
// final modulePath = "package:vector_math/vector_math.dart";  //"dart:ui";
// final docUrl = 'https://api.flutter.dev/flutter/vector_math/';
// final fsharpModuleName = "Dart.VectorMath";

String firstToUpper(String name) => name.substring(0, 1).toUpperCase() + name.substring(1);

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

  String paramAttributes(bool isConst, int namedIndex) {
    if (namedIndex >= 0) {
      return '[<${isConst ? 'IsConst; ' : ''}NamedParams${namedIndex != 0 ? '(fromIndex=$namedIndex)' : ''}>] ';
    }
    else if (isConst) {
      return '[<IsConst>] ';
    } else {
      return '';
    }
  }

  String renderGenericParams(Iterable<TypeParameter> genericParams) =>
    genericParams.isEmpty
      ? ''
      : '<${genericParams.map((e) => "'${e.element!.name}").join(', ')}>';
      // If we use e.name it may print `T extends ...`

  String renderGenericArgs(Iterable<DartType> genericParams) =>
    genericParams.isEmpty
      ? ''
      : '<${genericParams.map(renderType).join(', ')}>';

  List<DartType> getGenerics(DartType t) => t is ParameterizedType ? t.typeArguments : const <DartType>[];

  String renderGeneric(DartType t) {
    final gen = getGenerics(t);
    return gen.isEmpty ? "obj" : renderType(gen.first);
  }

  String renderType(DartType t, [isOptional = false]) {    
    final suffix = !isOptional && t.nullabilitySuffix == NullabilitySuffix.question ? " option" : "";
    if (t.isVoid) {
      return "unit";
    }
    else if (t.isDartCoreObject || t.isDynamic) {
      return "obj$suffix";
    }
    else if (t.isDartCoreBool) {
      return "bool$suffix";
    }
    else if (t.isDartCoreString) {
      return "string$suffix";
    }
    else if (t.isDartCoreInt) {
      return "int$suffix"; // int64?
    }
    else if (t.isDartCoreDouble) {
      return "float$suffix";
    }
    else if (t.isDartCoreList) {
      return "${renderGeneric(t)}[]$suffix";
    }
    else if (t.isDartCoreIterable) {
      return "${renderGeneric(t)} seq$suffix";
    }
    else if (t.isDartCoreMap) {
      return "Dictionary${renderGenericArgs(getGenerics(t))}$suffix";
    }
    else if (t.isDartCoreSet) {
      return "HashSet<${renderGeneric(t)}>$suffix";
    }
    else if (t is FunctionType) {
      final gen = t.parameters.map((p) => p.type).toList();
      if (gen.isEmpty) {
        return "(unit -> ${renderType(t.returnType)})";
      } else {
        return "(${gen.map(renderType).join(' -> ')} -> ${renderType(t.returnType)})";
      }
    }
    else {
      final gen = getGenerics(t);
      var name = t.element?.name ?? t.alias?.element.name ?? t.getDisplayString(withNullability: false);
      switch (name) {
        case "Duration":
          name = "TimeSpan";
          break;
        case "Uint8List":
          name = "byte[]";
          break;
        case "Uint16List":
          name = "uin16[]";
          break;
        case "Int32List":
          name = "int[]";
          break;
        case "Float32List":
          name = "single[]";
          break;
        case "Float64List":
          name = "float[]";
          break;
      }
      if (gen.isEmpty) {
        return (t is TypeParameterType ? "'$name" : name) + suffix;
      } else {
        return '$name${renderGenericArgs(gen)}$suffix'; 
      }
    }
  }

  String sanitize(String name) => keywords.contains(name) ? '``$name``' : name;

  RenderParamsResult renderParams(List<Parameter> parameters) {
    String renderParam(ParameterElement e) {
      return '${e.isOptional ? "?" : ""}${sanitize(e.name)}: ${renderType(e.type, e.isOptional)}';
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

  void generateStaticMember(StringBuffer buffer, String name, DartType returnType, { isConst = false, docComment = false, List<Parameter>? params, List<TypeParameter>? genericParams }) {
    // print("Generating bindings for static member $name");

    // final genericParams = fn.typeParameters;
    final renderedGenerics = genericParams != null ? renderGenericParams(genericParams) : '';
    final renderedParams = params != null ? renderParams(params) : null;
    final attributes = paramAttributes(isConst, renderedParams != null ? renderedParams.namedIndex : -1);
    final renderedParamsStr = renderedParams != null ? '(${renderedParams.rendered})' : '';
    final renderedReturnType = renderType(returnType);

    if (docComment) {
      buffer.writeln('  /// $docUrl$name.html');
    }
    buffer.writeln('  ${attributes}static member ${sanitize(name)}$renderedGenerics$renderedParamsStr: $renderedReturnType = nativeOnly');
    // buffer.writeln();
  }

  void generateEnum(StringBuffer buffer, Enum enum_) {    
    buffer.writeln('/// $docUrl${enum_.name}.html');
    buffer.writeln('[<ImportMember("$modulePath")>]');
    buffer.writeln('type ${enum_.name} =');

    final enumFields = enum_.allFields.where((element) => element is EnumField && element.isPublic).map((e) => e as EnumField);
    for (final enumField in enumFields) {
      buffer.writeln('  [<IsConst>] static member ${sanitize(enumField.name)}: ${enum_.name} = nativeOnly');
    }
    buffer.writeln();
  }

  // For now just declare the mixin as if it were an interface
  void generateMixin(StringBuffer buffer, Mixin mixin_) {    
    buffer.writeln('/// $docUrl${mixin_.name}-mixin.html');
    buffer.writeln('[<ImportMember("$modulePath")>]');
    buffer.writeln('type ${mixin_.name} =');
    buffer.writeln('  interface end');
    buffer.writeln();
  }

  void generateClass(StringBuffer buffer, Class class_) {    
    final parent = class_.supertype != null && class_.supertype!.isPublic ? class_.supertype : null;
    print("Generating bindings for class ${class_.name}${parent != null ? " : ${parent.name}" : ""}");

    final renderedGenerics = renderGenericParams(class_.typeParameters);
    var headerPrinted = false;
    var moreThanHeader = false;

    buffer.writeln('/// $docUrl${class_.name}-class.html');
    buffer.writeln('[<ImportMember("$modulePath")${class_.isAbstract ? "; AbstractClass" : ""}>]');

    // if (class_.name == "Widget") {
    //   buffer.writeln('type Widget =');
    //   buffer.writeln('  interface end');
    //   return;
    // }

    var defCons = class_.unnamedConstructor;
    if (defCons != null) {
      headerPrinted = true;
      final renderedParams = renderParams(defCons.parameters);
      buffer.writeln(
          'type ${class_.name}$renderedGenerics ${paramAttributes(defCons.isConst, renderedParams.namedIndex)}(${renderedParams.rendered}) =');

      if (parent != null) {
        moreThanHeader = true;
        final superGenerics = renderGenericArgs(parent.typeArguments.map((e) => e.type));

        final paramsSet = Set.from(defCons.parameters.map((e) => e.name));
        final superParamEls = (defCons.element as ConstructorElementImpl?)?.superConstructor?.parameters.where((p) => p.isRequiredPositional || p.isRequiredNamed) ?? <ParameterElement>[];
        final superParams = superParamEls.map((e) => paramsSet.contains(e.name) ? sanitize(e.name) : "nativeOnly");
        // final superParams = defCons.parameters.where((e) => e.element?.isSuperFormal ?? false).map((e) => sanitize(e.name));

        buffer.writeln('  inherit ${parent.name}$superGenerics(${superParams.join(", ")})');
      }
    }

    if (!headerPrinted) {
      headerPrinted = true;
      buffer.writeln('type ${class_.name}$renderedGenerics =');
    }

    final namedConstructors = class_.constructors.where((element) => !element.isUnnamedConstructor && element.isPublic);
    for (final cons in namedConstructors) {
      moreThanHeader = true;
      final renderedParams = renderParams(cons.parameters);
      final treated = sanitize(cons.name.substring(class_.name.length + 1));
      buffer.writeln(
          '  ${paramAttributes(cons.isConst, renderedParams.namedIndex)}static member $treated(${renderedParams.rendered}): ${class_.name}$renderedGenerics = nativeOnly'
      );
    }

    // Mainly intended for Icons
    final staticConstFields = class_.constantFields.where((element) => element.isStatic && element.field != null && !element.name.startsWith('_'));
    for (final fi in staticConstFields) {
      moreThanHeader = true;
      generateStaticMember(buffer, fi.name, fi.field!.type, isConst: fi.isConst);
    }

    if (!moreThanHeader) {
      buffer.writeln('  class end');
    }
    buffer.writeln();
  }

  void handleDependencies(Library lib, PackageGraph packageGraph) {
    final currentLibUri = lib.element.source.uri;
    final dependencies = Set<Dependency>.identity();
    for (final libEl in lib.element.importedLibraries) {
      if (libEl.isPrivate) continue;
      final dep = dependency(libEl, packageGraph);
      if (dep != null && dep.libraryUri != currentLibUri) {
        dependencies.add(dep);
      }
    }
    print('$lib dependencies:');
    for (final d in dependencies) {
      print(d);
    }
  }

  @override
  Future<void> generate(PackageGraph packageGraph, FileWriter writer) async {
    // print("Default: ${packageGraph.defaultPackageName}");

    final packages = packageGraph.packages;
    // final packages = [packageGraph.defaultPackage]; //packageGraph.packages

    final functions = <ModelFunctionTyped>[];

    for (final package in packages) {
      print("Package: ${package.name}");
      if (package.name != packageFilter) continue;
      print("Generating bindings for package: ${package.name}");

      final buffer = StringBuffer();
      buffer.writeln('namespace rec $fsharpModuleName');
      buffer.writeln();
      buffer.writeln('open System');
      buffer.writeln('open System.Collections.Generic');
      buffer.writeln('open Fable.Core');
      buffer.writeln('open Fable.Core.Dart');
      buffer.writeln();
      // buffer.writeln('let [<Literal>] private PATH = "$modulePath"');
      // buffer.writeln();

      bool libFilter(Library lib, String filter) {
        return filter.isEmpty ? true : lib.sourceFileName.replaceAll("\\", "/").contains(filter);
      }

      for (final lib in package.libraries) {
        // print("Module (library): ${lib.name}");
        if (!libFilter(lib, libraryFilter)) continue;
        print("Generating bindings for module (library): ${lib.sourceFileName}");

        // handleDependencies(lib, packageGraph);

        for (final enum_ in lib.publicEnums) {
          if (!libFilter(enum_.definingLibrary, defininingLibraryFilter)) continue;
          generateEnum(buffer, enum_);
        }

        for (final mixin_ in lib.publicMixins) {
          if (!libFilter(mixin_.definingLibrary, defininingLibraryFilter)) continue;
          generateMixin(buffer, mixin_);
        }

        for (final class_ in lib.publicClasses) {
          if (!libFilter(class_.definingLibrary, defininingLibraryFilter)) continue;
          generateClass(buffer, class_);
        }

        for (final fn in lib.publicFunctions) {
          if (!libFilter(fn.definingLibrary, defininingLibraryFilter)) continue;
          functions.add(fn);            
        }
      }

      if (functions.isNotEmpty) {
        final lastDot = fsharpModuleName.lastIndexOf('.');
        final className = lastDot >= 0 ? fsharpModuleName.substring(lastDot + 1) : fsharpModuleName;
        buffer.writeln('[<ImportAll("$modulePath")>]');
        buffer.writeln('type $className =');
        for (final fn in functions) {
          generateStaticMember(buffer, fn.name, fn.element!.returnType, isConst: fn.isConst, docComment: true, params: fn.parameters, genericParams: fn.typeParameters);
        }
      }

      writer.write('$fsharpModuleName.fs', buffer.toString());
    }
  }
}
