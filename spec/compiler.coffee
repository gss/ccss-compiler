if window?
  parser = require 'ccss-compiler'
else
  chai = require 'chai' unless chai
  parser = require '../lib/ccss-compiler'


parse = (source, expect) ->
  result = null
  describe source, ->
    it 'should do something', ->
      result = parser.parse source
      chai.expect(result).to.be.an 'object'
    it 'commands ✓', ->
      chai.expect(result.commands).to.eql expect.commands or []
    it 'selectors ✓', ->
      chai.expect(result.selectors).to.eql expect.selectors or []
      #chai.expect(result.vars).to.eql expect.vars or []
      #chai.expect(result.constraints).to.eql expect.constraints or []

describe 'CCSS-to-AST', ->
  it 'should provide a parse method', ->
    chai.expect(parser.parse).to.be.a 'function'

  # Basics
  # ====================================================================

  describe "/* Basics */", ->

    parse """
            10 <= 2 == 3 < 4 == 5 // chainning numbers, maybe should throw error?
          """
        ,
          {
            selectors: []
            commands: [
              ['lte', ['number', 10], ['number', 2]]
              ['eq', ['number', 2], ['number', 3]]
              ['lt', ['number', 3], ['number', 4]]
              ['eq', ['number', 4], ['number', 5]]
            ]
          }

    parse """
            [md-width] == ([width] * 2 - [gap] * 2) / 4 + 10 !require; // order of operations
          """
        ,
          {
            selectors: []
            commands: [
              ['eq',
                ['get', '[md-width]'],
                ['plus'
                  [ 'divide',
                    ['minus',
                      ['multiply',
                        ['get','[width]'],
                        ['number',2]
                      ],
                      ['multiply',
                        ['get','[gap]'],
                        ['number',2]
                      ]
                    ],
                    ['number',4]
                  ],
                  ['number',10]
                ],
                "require"]
            ]
          }


    parse """
            [grid-height] * #box2[width] <= 2 == 3 < 4 == 5 // w/ multiple statements containing variables and getters
          """
        ,
          {
            selectors: ["#box2"]
            commands: [
              ['lte', [
                'multiply', ['get', '[grid-height]'], ['get$', 'width', ['$id', 'box2']]
                ],
                ['number', 2]
              ]
              ['eq', ['number', 2], ['number', 3]]
              ['lt', ['number', 3], ['number', 4]]
              ['eq', ['number', 4], ['number', 5]]
            ]
          }


  # Name Normalization
  # ====================================================================

  describe "/* Normalize Names */", ->

    parse """
            #b[left] == [left];
            [left-col] == [col-left];
          """
        ,
          {
            selectors: ['#b']
            commands: [
              ['eq', ['get$', 'x', ['$id', 'b']], ['get', '[left]']]
              ['eq', ['get', '[left-col]'], ['get', '[col-left]']]
            ]
          }
    parse """
            #b[top] == [top];
          """
        ,
          {
            selectors: ['#b']
            commands: [
              ['eq',['get$','y',['$id','b']],['get','[top]']]
            ]
          }

    parse """
            [right] == ::window[right];
          """
        ,
          {
            selectors: ['::window']
            commands: [
              ['eq',['get','[right]'],['get$','width',['$reserved','window']]]
            ]
          }
    parse """
            [left] == ::window[left];
          """
        ,
          {
            selectors: ['::window']
            commands: [
              ['eq', ['get','[left]'], ['get$','x',['$reserved','window']]]
            ]
          }
    parse """
            [top] == ::window[top];
          """
        ,
          {
            selectors: ['::window']
            commands: [
              ['eq', ['get', '[top]'], ['get$','y',['$reserved','window']]]
            ]
          }
    parse """
            [bottom] == ::window[bottom];
          """
        ,
          {
            selectors: ['::window']
            commands: [
              ['eq', ['get','[bottom]'], ['get$','height',['$reserved','window']]]
            ]
          }

    parse """
            #b[cx] == [cx];
          """
        ,
          {
            selectors: ['#b']
            commands: [
              ['eq', ['get$', 'center-x',['$id', 'b']], ['get', '[cx]']]
            ]
          }
    parse """
            #b[cy] == [cy];
          """
        ,
          {
            selectors: ['#b']
            commands: [
              ['eq', ['get$','center-y',['$id', 'b']], ['get', '[cy]']]
            ]
          }


  # Strength
  # ====================================================================

  describe "/* Strength */", ->

    parse """
            4 == 5 == 6 !strong10 // w/ strength and weight
          """
        ,
          {
            selectors: []
            commands: [
              ['eq', ['number', 4], ['number', 5], 'strong', 10]
              ['eq', ['number', 5], ['number', 6], 'strong', 10]
            ]
          }


  # Stays
  # ====================================================================

  describe "/* Stays */", ->

    parse """
            @-gss-stay #box[width], [grid-height];
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['stay',['get$','width',['$id','box']],['get','[grid-height]']]
            ]
          }
    parse """
            @stay #box[width], [grid-height];
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['stay',['get$','width',['$id','box']],['get','[grid-height]']]
            ]
          }


  # Expressions
  # ====================================================================

  describe "/* Variable Expressions */", ->

    parse """
            #box[right] == #box2[x];
          """
        ,
          {
            selectors: [
              '#box'
              '#box2'
            ]
            commands: [
              ['eq', ['get$','right',['$id','box']], ['get$','x',['$id','box2']]]
            ]
          }


  # Adv Selectors
  # ====================================================================

  describe '/* Advanced Selectors */', ->

    parse """
            (html #main .boxes)[width] == [col-width]
          """
        ,
          {
            selectors: [
              'html #main .boxes'
            ]
            commands: [
              ['eq',['get$','width',['$all','html #main .boxes']], ['get','[col-width]']]
            ]
          }

    parse """
            (html #main:not(.disabled) .boxes[data-target="true"])[width] == [col-width]
          """
        ,
          {
            selectors: [
              'html #main:not(.disabled) .boxes[data-target=\"true\"]'
            ]
            commands: [
              ['eq', ['get$','width',['$all','html #main:not(.disabled) .boxes[data-target=\"true\"]']], ['get', '[col-width]']]
            ]
          }


  # Pseudos
  # ====================================================================

  describe '/* Reserved Pseudos */', ->

    parse """
            ::[width] == ::parent[width]
          """
        ,
          {
            selectors: [
              '::this'
              '::parent'
            ]
            commands: [
              ['eq', ['get$','width',['$reserved','this']], ['get$','width',['$reserved', 'parent']]]
            ]
          }

    # viewport gets normalized to window
    parse """
            ::scope[width] == ::this[width] == ::document[width] == ::viewport[width] == ::window[height]
          """
        ,
          {
            selectors: [
              '::scope'
              '::this'
              '::document'
              '::window'
            ]
            commands: [
              ['eq', ['get$','width',['$reserved','scope']],    ['get$','width',['$reserved','this']]]
              ['eq', ['get$','width',['$reserved','this']],     ['get$','width',['$reserved','document']]]
              ['eq', ['get$','width',['$reserved','document']], ['get$','width',['$reserved','window']]]
              ['eq', ['get$','width',['$reserved','window']],   ['get$','height',['$reserved','window']]]
            ]
          }


  # Intrinsics
  # ====================================================================

  describe '/ Intrinsic Props /', ->

    # should do nothing special...
    parse """
            #box[width] == #box[intrinsic-width];
            [grid-col-width] == #box[intrinsic-width];
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['eq',['get$','width',['$id','box']], ['get$','intrinsic-width',['$id','box']]]
              ['eq',['get','[grid-col-width]'], ['get$','intrinsic-width',['$id','box']]]
            ]
          }
    parse """
            #box[right] == #box[intrinsic-right];
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['eq',['get$','right',['$id','box']],['get$','intrinsic-right',['$id','box']]]
            ]
          }


  # Virtual Elements
  # ====================================================================

  describe '/ "Virtual Elements" /', ->

    parse """
            @virtual "Zone";
          """
        ,
          {
            selectors: []
            commands: [
              ['virtual','Zone']
            ]
          }


    parse """
            "Zone"[width] == 100;
          """
        ,
          {
            selectors: []
            commands: [
              ['eq', ['get$','width',['$virtual','Zone']], ['number',100]]
            ]
          }

    parse """
            "A"[left] == "1"[top];
          """
        ,
          {
            selectors: []
            commands: [
              ['eq', ['get$','x',['$virtual','A']],['get$','y',['$virtual','1']]]
            ]
          }

    parse '"box"[right] == "box2"[left];',
          {
            selectors: []
            commands: [
              ['eq', ['get$','right',['$virtual','box']],['get$','x',['$virtual','box2']]]
            ]
          }



  # Conditionals
  # ====================================================================

  describe '/ @? conditionals /', ->

    parse """
            @cond #box[right] == #box2[x];
          """
        ,
          {
            selectors: [
              '#box'
              '#box2'
            ]
            commands: [
              ['?==', ['get$','right',['$id','box']], ['get$','x',['$id','box2']]]
            ]
          }

    parse """
            @cond 2 * [right] == [x] + 100;
          """
        ,
          {
            selectors: [
            ]
            commands: [
              ['?==',['multiply',['number',2],['get','[right]']], ['plus',['get','[x]'],['number',100]] ]
            ]
          }

    parse """
            @cond #box[right] != #box2[x] AND #box[width] <= #box2[width];
          """
        ,
          {
            selectors: [
              '#box'
              '#box2'
            ]
            commands: [
              ["&&"
                ['?!=', ['get$','right',['$id','box']], ['get$','x',['$id','box2']]],
                ['?<=', ['get$','width',['$id','box']], ['get$','width',['$id','box2']]]
              ]
            ]
          }

    parse """
            @cond (#box[right] != #box2[x]) AND (#box[width] <= #box2[width]);
          """
        ,
          {
            selectors: [
              '#box'
              '#box2'
            ]
            commands: [
              ["&&"
                ['?!=', ['get$','right',['$id','box']], ['get$','x',['$id','box2']]],
                ['?<=', ['get$','width',['$id','box']], ['get$','width',['$id','box2']]]
              ]
            ]
          }

    parse """
            @cond (#box[right] != #box2[x]) and (#box[width] <= #box2[width] or [x] == 100);
          """
        ,
          {
            selectors: [
              '#box'
              '#box2'
            ]
            commands: [
              ["&&"
                ['?!=', ['get$','right',['$id','box']], ['get$','x',['$id','box2']]],
                ["||"
                  ['?<=', ['get$','width',['$id','box']], ['get$','width',['$id','box2']]],
                  ['?==', ['get','[x]'],['number',100]]
                ]
              ]
            ]
          }


  # JS Shit... WIP
  # ====================================================================

  describe '/ js layout hooks /', ->

    parse """
            [left-col] == [col-left];
            @for-each .box ```
            function (el,exp,engine) {
              var asts =[];
              asts.push();
            }
            ```;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [

              ['eq', ['get', '[left-col]'], ['get', '[col-left]']]
              [
                'for-each',
                ['$class', 'box'],
                ['js',"""function (el,exp,engine) {
                    var asts =[];
                    asts.push();
                  }""" ]
              ]
            ]
          }

    parse """
            @for-all .box ```
            function (query,engine) {
              var asts =[];
              asts.push();
            }
            ```;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'for-all',
                ['$class', 'box'],
                ['js',"""function (query,engine) {
                    var asts =[];
                    asts.push();
                  }""" ]
              ]
            ]
          }


  # Chains... WIP
  # ====================================================================

  describe '/ @chain /', ->

    parse """
            @chain .box bottom(==)top;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','bottom','top']
              ]
            ]
          }


    parse """
            @chain .box width();
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','width','width']
              ]
            ]
          }

    parse """
            @chain .box width() height(>=10>=) bottom(<=)top;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','width','width'],
                ['gte-chain','height',['number',10]],
                ['gte-chain',['number',10],'height'],
                ['lte-chain','bottom','top']
              ]
            ]
          }

    parse """
            @chain .box width([hgap]*2);
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','width',['multiply',['get','[hgap]'],['number',2]]]
                ['eq-chain',['multiply',['get','[hgap]'],['number',2]],'width']
              ]
            ]
          }

    parse """
            @chain .box width(+[hgap]*2);
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain',['plus-chain','width',['multiply',['get','[hgap]'],['number',2]]],'width']
              ]
            ]
          }

    parse """
            @chain .box right(+10==)left;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain',['plus-chain','right',['number',10]],'left']
              ]
            ]
          }

    parse """
            @chain .box bottom(==!require)top;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','bottom','top','require']
              ]
            ]
          }


    parse """
            @chain .box bottom(==!require)top width() height(!weak);
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','bottom','top',   'require']
                ['eq-chain','width', 'width']
                ['eq-chain','height','height',  'weak']
              ]
            ]
          }



    ### Not valid in parser at this stage
    parse """
            @chain .box height(==2+)center-x;
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              [
                'chain',
                ['$class', 'box'],
                ['eq-chain','height',['multiply-chain',['number',2],'center-x']]
              ]
            ]
          }
    ###


    ###
    parse """
            @chain .box width() {
              :first[width] == :last[width];
              :3rd[height] >= 2*:4th[height];
            };
          """
        ,
          {
            selectors: [
              '.box'
            ]
            commands: [
              ['chain', ['$class', 'box'], ['eq-chain','width','width']]
              ['var', '.box:first[width]', 'width', ['$contextual',':first',['$class', 'box']]]
              ['eq',['get','.box:first[width]'],['get','.box:last[width]']]
              ['var', '.box:first[width]', 'width', ['$contextual',':first',['$class', 'box']]]
            ]
          }
    ###

  ###
  describe '/ contextual ::this iterators /', ->

    parse """
            .node[height] >= .node(.inports)[height];
            .box {
              width: == ::this(.header)[width];
            }
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['var','.box[width]', 'width', ['$class', 'box']]
              ['var','.box(.header)[width]', 'width', ['$class', 'header', ['$class', 'box']]]
              ['foreach', ['$class', 'box'],
              ['var','#box[intrinsic-width]', 'intrinsic-width', ['$id', 'box']]
              ['eq',['get','#box[width]','#box'],['get','#box[intrinsic-width]','#box']]
              ['var','[grid-col-width]']
              ['eq',['get','[grid-col-width]'],['get','#box[intrinsic-width]','#box']]
            ]
          }
  ###

  # 2D
  # ====================================================================

  describe '/* 2D */', ->

    parse """
            #box1[size] == #box2[size];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'width', ['$id', 'box1']], ['get$', 'width', ['$id', 'box2']]],
              ['eq', ['get$', 'height', ['$id', 'box1']], ['get$', 'height', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[position] == #box2[position];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'x', ['$id', 'box1']], ['get$', 'x', ['$id', 'box2']]],
              ['eq', ['get$', 'y', ['$id', 'box1']], ['get$', 'y', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[top-right] == #box2[center];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'right', ['$id', 'box1']], ['get$', 'center-x', ['$id', 'box2']]],
              ['eq', ['get$', 'top', ['$id', 'box1']], ['get$', 'center-y', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[bottom-right] == #box2[center];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'right', ['$id', 'box1']], ['get$', 'center-x', ['$id', 'box2']]],
              ['eq', ['get$', 'bottom', ['$id', 'box1']], ['get$', 'center-y', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[bottom-left] == #box2[center];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'left', ['$id', 'box1']], ['get$', 'center-x', ['$id', 'box2']]],
              ['eq', ['get$', 'bottom', ['$id', 'box1']], ['get$', 'center-y', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[top-left] == #box2[center];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'left', ['$id', 'box1']], ['get$', 'center-x', ['$id', 'box2']]],
              ['eq', ['get$', 'top', ['$id', 'box1']], ['get$', 'center-y', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[size] == #box2[intrinsic-size];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'width', ['$id', 'box1']], ['get$', 'intrinsic-width', ['$id', 'box2']]],
              ['eq', ['get$', 'height', ['$id', 'box1']], ['get$', 'intrinsic-height', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[top-left] == #box2[bottom-right];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'left', ['$id', 'box1']], ['get$', 'right', ['$id', 'box2']]]
              ['eq', ['get$', 'top', ['$id', 'box1']], ['get$', 'bottom', ['$id', 'box2']]],
            ]
          }

    parse """
            #box1[size] == #box2[width];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'width', ['$id', 'box1']], ['get$', 'width', ['$id', 'box2']]],
            ]
          }

    parse """
            #box1[size] == #box2[height];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'height', ['$id', 'box1']], ['get$', 'height', ['$id', 'box2']]]
            ]
          }

    parse """
            #box1[width] == #box2[size];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'width', ['$id', 'box1']], ['get$', 'width', ['$id', 'box2']]],
            ]
          }

    parse """
            #box1[height] == #box2[size];
          """
        ,
          {
            selectors: [
              '#box1'
              '#box2'
            ]
            commands: [
              ['eq', ['get$', 'height', ['$id', 'box1']], ['get$', 'height', ['$id', 'box2']]]
            ]
          }

    parse """
            @-gss-stay #box[size];
          """
        ,
          {
            selectors: [
              '#box'
            ]
            commands: [
              ['stay', ['get$', 'width', ['$id','box']]]
              ['stay', ['get$', 'height', ['$id','box']]]
            ]
          }
