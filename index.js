let DERIVE_ADDRESSES = 1
document.addEventListener('DOMContentLoaded', () => {
  window.brute.onclick = brutePasswordGPU
  window['show-settings'].onclick = () => {
    window['brute-pane'].style.display = 'none'
    window['settings-pane'].style.display = 'block'
  }
  window['hide-settings'].onclick = () => {
    window['brute-pane'].style.display = 'block'
    window['settings-pane'].style.display = 'none'
  }
  window.derive.onchange = () => {
    DERIVE_ADDRESSES = Number(window.derive.value)
    window.deriveView.innerText = Math.max(DERIVE_ADDRESSES, 1)
  }
  window.derive.value = DERIVE_ADDRESSES
  window.deriveView.innerText = DERIVE_ADDRESSES

  async function checkInput() {
    window.brute.style.visibility = await validateInput() ? 'visible' : 'hidden'
  }
  window.bipmask.onchange = checkInput
  window.bipmask.oninput = checkInput
  window.addrlist.onchange = checkInput
  window.addrlist.oninput = checkInput
  checkInput()
})

async function brutePasswordGPU() {
    let stopped = false
    const { bip39mask, addrHash160list, addrTypes } = await validateInput()
    const addrType = addrTypes[0]
    window.brute.onclick = () => { stopped = true }
    window.brute.innerText = '🛑 STOP'
    
    const batchSize = 1024 * 32
    const WORKGROUP_SIZE = 64
    const { name, clean, inference, buildShader, swapBuffers } = await webGPUinit({
      eccType: addrType === 'solana' ? 'ed25519' : 'secp256k1', BUF_SIZE: batchSize*128
    })
    const PASSWORD_LISTS = [
      { url: 'forced-browsing/all.txt', filePasswords: 43135 },
      { url: 'usernames.txt', filePasswords: 403335 },
      { url: '1000000-password-seclists.txt', filePasswords: 1000000 },
      { url: '2151220-passwords.txt', filePasswords: 2151220 },
      { url: '38650-password-sktorrent.txt', filePasswords: 38650 },
      { url: '38650-username-sktorrent.txt', filePasswords: 38650 },
      { url: 'uniqpass-v16-passwords.txt', filePasswords: 2151220 },
      { url: 'cain.txt', filePasswords: 306706 },
      { url: 'us-cities.txt', filePasswords: 20580 },
      { url: '7-more-passwords.txt', filePasswords: 528136 },
      { url: '8-more-passwords.txt', filePasswords: 61682 },
      { url: 'facebook-firstnames.txt', filePasswords: 4347667 },
    ]
    // PASSWORD_LISTS.sort((a, b) => a.filePasswords - b.filePasswords)
    const pipeline = await buildEntirePipeline({
        addrType, MNEMONIC: bip39mask, WORKGROUP_SIZE, buildShader, swapBuffers, hashList: addrHash160list
    })
    log(`[${name}]\nBruteforce init...`, true)
    let curList = 0
    let listName = PASSWORD_LISTS[curList].url
    let filePasswords = PASSWORD_LISTS[curList++].filePasswords
    let nextBatch = await getPasswords(`https://duyet.github.io/bruteforce-database/${listName}`)
    let processedPasswords = 0
    while (!stopped) {
        const inp = await nextBatch(batchSize)
        if (!inp && curList < PASSWORD_LISTS.length) {
          listName = PASSWORD_LISTS[curList].url
          filePasswords = PASSWORD_LISTS[curList++].filePasswords
          nextBatch = await getPasswords(`https://duyet.github.io/bruteforce-database/${listName}`)
          processedPasswords = 0
          continue
        }
        if (!inp && curList >= PASSWORD_LISTS.length) {
          log(`Password not found :(`, true)
          break
        }
        
        const start = performance.now()
        out = await inference({ shaders: pipeline, inp: new Uint32Array(inp.passwords), count: batchSize })
        const time = (performance.now() - start) / 1000
        const speed = batchSize / time | 0
        processedPasswords += inp.count
        const progress = (processedPasswords / filePasswords * 100).toFixed(1).padStart(4, '')
        log(`[${name}]\n${listName} (${curList}/${PASSWORD_LISTS.length}) ${progress}% ${speed} passwords/s`, true)
        if (out[0] !== 0xffffffff) {
            const passBuf = new Uint8Array(inp.passwords)
            const passBufIndex = new Uint32Array(inp.passwords, 128)
            const index = passBufIndex[out[0]]
            const index2 = passBufIndex[out[0] + 1]
            log(`FOUND :)\nPassword: ${new TextDecoder().decode(passBuf.slice(index, index2 - 1))}`, true)
            break
        }
    }

    clean()
    window.brute.onclick = brutePasswordGPU
    window.brute.innerText = 'Brute'
}

async function validateInput() {
  window.output.innerHTML = ''
  const bip39mask = window.bipmask.value
  let result = true
  const words = bip39mask.trim().split(/[\s \t]+/)
  if (![12, 15, 18, 24].includes(words.length)) {
      window.output.innerHTML += `Expected 12/15/18/24 words, got ${words.length}\n`
      result = false
  }
  let asterisks = 0
  for (let word of words) {
    if (word === '*') { asterisks++; continue }
    for (let wordPart of word.split(',')) {
      if (!biplist.includes(wordPart)) {
        window.output.innerHTML += `${wordPart} is invalid bip39 word\n`
        result = false
      }
    }
  }
  if (asterisks > 2) {
    window.output.innerHTML += `Can't brute with ${asterisks} * - too long to brute\n`
    result = false
  }
  const addrlist = window.addrlist.value.split('\n').map(x => x.trim()).filter(x => x)
  if (addrlist.length === 0) {
    window.output.innerHTML = `Enter at least 1 address\n`;
    result = false
  }
  const addrHash160list = []
  let addrTypes = new Set()
  for (let addr of addrlist) {
    const { hash160, type } = await addrToScriptHash(addr) || {}
    if (hash160) {
      addrTypes.add(type)
      addrHash160list.push(hash160)
    } else {
      window.output.innerHTML += `${addr} is invalid address\n`
      result = false
    }
  }
  addrTypes = Array.from(addrTypes)
  if (addrTypes.length > 1) {
    window.output.innerHTML += `WARNING! Multiple address types: ${addrTypes.join(', ')}\nOnly ${addrTypes[0]} will be used\n`;
  }
  return result && { bip39mask: words.join(' '), addrHash160list, addrTypes }
}

async function addrToScriptHash(address) {
    const sha256HashSync = async (data) => {
      return new Uint8Array(await crypto.subtle.digest('SHA-256', new Uint8Array(data)))
    }
    if (address.match(/^0x[0-9a-fA-F]{40}$/)) {
      return { hash160: hexToUint8Array(address.slice(2)), type: 'eth' }
    }
    if (address.startsWith('bc1')) {
      const hash160 = decodeBech32(address)
      return hash160 && { hash160, type: 'p2wphk' }
    }
    let decodedData = base58Decode(address)
    if (!decodedData) return null
    const doubleSha256 = await sha256HashSync(await sha256HashSync(decodedData.slice(0, -4)))
    const checksumValid = Array.from(doubleSha256.slice(0, 4)).every((byte, i) => byte === decodedData.slice(-4)[i])
    if (!checksumValid && isSolPubkey(decodedData)) {
      return { hash160: decodedData, type: 'solana' }
    }
    if (!checksumValid) return null
    const type = { '0': 'p2pkh', '5': 'p2sh', '65': 'tron' }[decodedData[0]]
    if (!type) return null
    return { hash160: decodedData.slice(1, 21), type }
}

function isSolPubkey(key) {
    const P = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffedn;
    const D = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3n;
    const M = (a, b = P) => (b + a % b) % b;
    function modExp(base, exponent) {
        let result = 1n; base = M(base);
        while (exponent > 0n) {
            if (exponent % 2n === 1n) { result = M(result * base); }
            exponent = exponent >> 1n;
            base = M(base * base);
        }
        return result;
    }

    if (key.length !== 32) return false
    const y = BigInt('0x'+Array.from(key).map(x => x.toString(16).padStart(2, '0')).reverse().join('')) & ((1n << 255n) - 1n)
    const u = M(y * y - 1n);
    const v = M(D * y * y + 1n);
    let x = M(u * M(v ** 3n) * modExp(u * M(v ** 7n), (P - 5n) / 8n, P)); // (uv³)(uv⁷)^(p-5)/8
    return M(v * x * x) === u || M(v * x * x) === M(-u)
}

function hexToUint8Array(hexString) {
    const bytes = [];
    for (let i = 0; i < hexString.length; i += 2) {
        bytes.push(parseInt(hexString.substr(i, 2), 16));
    }
    return new Uint8Array(bytes);
}

function base58Decode(str) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const bytes = [0];
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    const value = alphabet.indexOf(char);
    if (value === -1) return null;
    let carry = value;
    for (let j = 0; j < bytes.length; j++) {
      carry += bytes[j] * 58;
      bytes[j] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.push(carry & 0xff);
      carry >>= 8;
    }
  }
  let zeros = 0;
  while (str[zeros] === '1') zeros++;
  const result = new Uint8Array(zeros + bytes.length);
  for (let i = 0; i < bytes.length; i++) {
    result[result.length - 1 - i] = bytes[i];
  }
  return result;
}

function decodeBech32(address) {
  if (typeof address !== 'string') return null
  const lower = address.toLowerCase()
  if (lower !== address && address.toUpperCase() !== address) return null
  address = lower
  const SEP = address.lastIndexOf('1')
  if (SEP < 1 || SEP + 7 > address.length) return null
  const hrp = address.slice(0, SEP)
  const dataPart = address.slice(SEP + 1)
  if (!(hrp === 'bc' || hrp === 'tb' || hrp === 'bcrt')) return null
  const CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l'
  const CHARMAP = (() => {
    const map = new Int16Array(128).fill(-1)
    for (let i = 0; i < CHARSET.length; i++) map[CHARSET.charCodeAt(i)] = i
    return map
  })();
  const data = new Uint8Array(dataPart.length)
  for (let i = 0; i < dataPart.length; i++) {
    const v = dataPart.charCodeAt(i) < 128 ? CHARMAP[dataPart.charCodeAt(i)] : -1
    if (v === -1) return null
    data[i] = v
  }
  function hrpExpand(h) {
    const ret = []
    for (let i = 0; i < h.length; i++) ret.push(h.charCodeAt(i) >> 5)
    ret.push(0)
    for (let i = 0; i < h.length; i++) ret.push(h.charCodeAt(i) & 31)
    return ret
  }
  function polymod(values) {
    const GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    let chk = 1
    for (let p = 0; p < values.length; p++) {
      const top = chk >>> 25
      chk = ((chk & 0x1ffffff) << 5) ^ values[p]
      for (let i = 0; i < 5; i++) {
        if ((top >>> i) & 1) chk ^= GEN[i]
      }
    }
    return chk >>> 0;
  }
  const BECH32_CONST  = 1 >>> 0
  const BECH32M_CONST = 0x2bc830a3 >>> 0
  const values = new Uint8Array(hrpExpand(hrp).concat(Array.from(data)))
  const pm = polymod(values)
  const encConst = pm === BECH32_CONST ? 'bech32' :
                   pm === BECH32M_CONST ? 'bech32m' : null
  if (!encConst) return null
  const payload = data.slice(0, data.length - 6)
  if (payload.length === 0) return null
  const version = payload[0]
  if (version > 16) return null
  if ((version === 0 && encConst !== 'bech32') ||
      (version !== 0 && encConst !== 'bech32m')) {
    return null
  }

  function convertBits(data5, from, to, pad) {
    let acc = 0, bits = 0, out = []
    const maxv = (1 << to) - 1
    for (let i = 0; i < data5.length; i++) {
      const value = data5[i]
      if (value < 0 || value >> from) return null
      acc = (acc << from) | value
      bits += from
      while (bits >= to) {
        bits -= to
        out.push((acc >> bits) & maxv)
      }
    }
    if (pad) {
      if (bits) out.push((acc << (to - bits)) & maxv);
    } else if (bits >= from || ((acc << (to - bits)) & maxv)) {
      return null
    }
    return new Uint8Array(out)
  }

  const program5 = payload.slice(1)
  const program = convertBits(program5, 5, 8, false)
  if (!program) return null
  if (program.length < 2 || program.length > 40) return null
  if (version === 0 && !(program.length === 20 || program.length === 32)) return null
  if (program.length !== 20) return null
  return program
}

var biplist = ("abandon,ability,able,about,above,absent,absorb,abstract,absurd,abuse,access,accident,account,accuse,achieve," +
"acid,acoustic,acquire,across,act,action,actor,actress,actual,adapt,add,addict,address,adjust,admit,adult,advance,advice,aerobic," +
"affair,afford,afraid,again,age,agent,agree,ahead,aim,air,airport,aisle,alarm,album,alcohol,alert,alien,all,alley,allow,almost," +
"alone,alpha,already,also,alter,always,amateur,amazing,among,amount,amused,analyst,anchor,ancient,anger,angle,angry,animal," +
"ankle,announce,annual,another,answer,antenna,antique,anxiety,any,apart,apology,appear,apple,approve,april,arch,arctic,area," +
"arena,argue,arm,armed,armor,army,around,arrange,arrest,arrive,arrow,art,artefact,artist,artwork,ask,aspect,assault,asset,assist," +
"assume,asthma,athlete,atom,attack,attend,attitude,attract,auction,audit,august,aunt,author,auto,autumn,average,avocado,avoid," +
"awake,aware,away,awesome,awful,awkward,axis,baby,bachelor,bacon,badge,bag,balance,balcony,ball,bamboo,banana,banner,bar,barely," +
"bargain,barrel,base,basic,basket,battle,beach,bean,beauty,because,become,beef,before,begin,behave,behind,believe,below,belt," +
"bench,benefit,best,betray,better,between,beyond,bicycle,bid,bike,bind,biology,bird,birth,bitter,black,blade,blame,blanket," +
"blast,bleak,bless,blind,blood,blossom,blouse,blue,blur,blush,board,boat,body,boil,bomb,bone,bonus,book,boost,border,boring," +
"borrow,boss,bottom,bounce,box,boy,bracket,brain,brand,brass,brave,bread,breeze,brick,bridge,brief,bright,bring,brisk,broccoli," +
"broken,bronze,broom,brother,brown,brush,bubble,buddy,budget,buffalo,build,bulb,bulk,bullet,bundle,bunker,burden,burger,burst," +
"bus,business,busy,butter,buyer,buzz,cabbage,cabin,cable,cactus,cage,cake,call,calm,camera,camp,can,canal,cancel,candy,cannon," +
"canoe,canvas,canyon,capable,capital,captain,car,carbon,card,cargo,carpet,carry,cart,case,cash,casino,castle,casual,cat,catalog," +
"catch,category,cattle,caught,cause,caution,cave,ceiling,celery,cement,census,century,cereal,certain,chair,chalk,champion,change," +
"chaos,chapter,charge,chase,chat,cheap,check,cheese,chef,cherry,chest,chicken,chief,child,chimney,choice,choose,chronic,chuckle," +
"chunk,churn,cigar,cinnamon,circle,citizen,city,civil,claim,clap,clarify,claw,clay,clean,clerk,clever,click,client,cliff,climb," +
"clinic,clip,clock,clog,close,cloth,cloud,clown,club,clump,cluster,clutch,coach,coast,coconut,code,coffee,coil,coin,collect," +
"color,column,combine,come,comfort,comic,common,company,concert,conduct,confirm,congress,connect,consider,control,convince," +
"cook,cool,copper,copy,coral,core,corn,correct,cost,cotton,couch,country,couple,course,cousin,cover,coyote,crack,cradle,craft," +
"cram,crane,crash,crater,crawl,crazy,cream,credit,creek,crew,cricket,crime,crisp,critic,crop,cross,crouch,crowd,crucial,cruel," +
"cruise,crumble,crunch,crush,cry,crystal,cube,culture,cup,cupboard,curious,current,curtain,curve,cushion,custom,cute,cycle," +
"dad,damage,damp,dance,danger,daring,dash,daughter,dawn,day,deal,debate,debris,decade,december,decide,decline,decorate,decrease," +
"deer,defense,define,defy,degree,delay,deliver,demand,demise,denial,dentist,deny,depart,depend,deposit,depth,deputy,derive," +
"describe,desert,design,desk,despair,destroy,detail,detect,develop,device,devote,diagram,dial,diamond,diary,dice,diesel,diet," +
"differ,digital,dignity,dilemma,dinner,dinosaur,direct,dirt,disagree,discover,disease,dish,dismiss,disorder,display,distance," +
"divert,divide,divorce,dizzy,doctor,document,dog,doll,dolphin,domain,donate,donkey,donor,door,dose,double,dove,draft,dragon," +
"drama,drastic,draw,dream,dress,drift,drill,drink,drip,drive,drop,drum,dry,duck,dumb,dune,during,dust,dutch,duty,dwarf,dynamic," +
"eager,eagle,early,earn,earth,easily,east,easy,echo,ecology,economy,edge,edit,educate,effort,egg,eight,either,elbow,elder,electric," +
"elegant,element,elephant,elevator,elite,else,embark,embody,embrace,emerge,emotion,employ,empower,empty,enable,enact,end,endless," +
"endorse,enemy,energy,enforce,engage,engine,enhance,enjoy,enlist,enough,enrich,enroll,ensure,enter,entire,entry,envelope,episode," +
"equal,equip,era,erase,erode,erosion,error,erupt,escape,essay,essence,estate,eternal,ethics,evidence,evil,evoke,evolve,exact," +
"example,excess,exchange,excite,exclude,excuse,execute,exercise,exhaust,exhibit,exile,exist,exit,exotic,expand,expect,expire," +
"explain,expose,express,extend,extra,eye,eyebrow,fabric,face,faculty,fade,faint,faith,fall,false,fame,family,famous,fan,fancy," +
"fantasy,farm,fashion,fat,fatal,father,fatigue,fault,favorite,feature,february,federal,fee,feed,feel,female,fence,festival," +
"fetch,fever,few,fiber,fiction,field,figure,file,film,filter,final,find,fine,finger,finish,fire,firm,first,fiscal,fish,fit," +
"fitness,fix,flag,flame,flash,flat,flavor,flee,flight,flip,float,flock,floor,flower,fluid,flush,fly,foam,focus,fog,foil,fold," +
"follow,food,foot,force,forest,forget,fork,fortune,forum,forward,fossil,foster,found,fox,fragile,frame,frequent,fresh,friend," +
"fringe,frog,front,frost,frown,frozen,fruit,fuel,fun,funny,furnace,fury,future,gadget,gain,galaxy,gallery,game,gap,garage,garbage," +
"garden,garlic,garment,gas,gasp,gate,gather,gauge,gaze,general,genius,genre,gentle,genuine,gesture,ghost,giant,gift,giggle," +
"ginger,giraffe,girl,give,glad,glance,glare,glass,glide,glimpse,globe,gloom,glory,glove,glow,glue,goat,goddess,gold,good,goose," +
"gorilla,gospel,gossip,govern,gown,grab,grace,grain,grant,grape,grass,gravity,great,green,grid,grief,grit,grocery,group,grow," +
"grunt,guard,guess,guide,guilt,guitar,gun,gym,habit,hair,half,hammer,hamster,hand,happy,harbor,hard,harsh,harvest,hat,have," +
"hawk,hazard,head,health,heart,heavy,hedgehog,height,hello,helmet,help,hen,hero,hidden,high,hill,hint,hip,hire,history,hobby," +
"hockey,hold,hole,holiday,hollow,home,honey,hood,hope,horn,horror,horse,hospital,host,hotel,hour,hover,hub,huge,human,humble," +
"humor,hundred,hungry,hunt,hurdle,hurry,hurt,husband,hybrid,ice,icon,idea,identify,idle,ignore,ill,illegal,illness,image,imitate," +
"immense,immune,impact,impose,improve,impulse,inch,include,income,increase,index,indicate,indoor,industry,infant,inflict,inform," +
"inhale,inherit,initial,inject,injury,inmate,inner,innocent,input,inquiry,insane,insect,inside,inspire,install,intact,interest," +
"into,invest,invite,involve,iron,island,isolate,issue,item,ivory,jacket,jaguar,jar,jazz,jealous,jeans,jelly,jewel,job,join," +
"joke,journey,joy,judge,juice,jump,jungle,junior,junk,just,kangaroo,keen,keep,ketchup,key,kick,kid,kidney,kind,kingdom,kiss," +
"kit,kitchen,kite,kitten,kiwi,knee,knife,knock,know,lab,label,labor,ladder,lady,lake,lamp,language,laptop,large,later,latin," +
"laugh,laundry,lava,law,lawn,lawsuit,layer,lazy,leader,leaf,learn,leave,lecture,left,leg,legal,legend,leisure,lemon,lend,length," +
"lens,leopard,lesson,letter,level,liar,liberty,library,license,life,lift,light,like,limb,limit,link,lion,liquid,list,little," +
"live,lizard,load,loan,lobster,local,lock,logic,lonely,long,loop,lottery,loud,lounge,love,loyal,lucky,luggage,lumber,lunar," +
"lunch,luxury,lyrics,machine,mad,magic,magnet,maid,mail,main,major,make,mammal,man,manage,mandate,mango,mansion,manual,maple," +
"marble,march,margin,marine,market,marriage,mask,mass,master,match,material,math,matrix,matter,maximum,maze,meadow,mean,measure," +
"meat,mechanic,medal,media,melody,melt,member,memory,mention,menu,mercy,merge,merit,merry,mesh,message,metal,method,middle," +
"midnight,milk,million,mimic,mind,minimum,minor,minute,miracle,mirror,misery,miss,mistake,mix,mixed,mixture,mobile,model,modify," +
"mom,moment,monitor,monkey,monster,month,moon,moral,more,morning,mosquito,mother,motion,motor,mountain,mouse,move,movie,much," +
"muffin,mule,multiply,muscle,museum,mushroom,music,must,mutual,myself,mystery,myth,naive,name,napkin,narrow,nasty,nation,nature," +
"near,neck,need,negative,neglect,neither,nephew,nerve,nest,net,network,neutral,never,news,next,nice,night,noble,noise,nominee," +
"noodle,normal,north,nose,notable,note,nothing,notice,novel,now,nuclear,number,nurse,nut,oak,obey,object,oblige,obscure,observe," +
"obtain,obvious,occur,ocean,october,odor,off,offer,office,often,oil,okay,old,olive,olympic,omit,once,one,onion,online,only," +
"open,opera,opinion,oppose,option,orange,orbit,orchard,order,ordinary,organ,orient,original,orphan,ostrich,other,outdoor,outer," +
"output,outside,oval,oven,over,own,owner,oxygen,oyster,ozone,pact,paddle,page,pair,palace,palm,panda,panel,panic,panther,paper," +
"parade,parent,park,parrot,party,pass,patch,path,patient,patrol,pattern,pause,pave,payment,peace,peanut,pear,peasant,pelican," +
"pen,penalty,pencil,people,pepper,perfect,permit,person,pet,phone,photo,phrase,physical,piano,picnic,picture,piece,pig,pigeon," +
"pill,pilot,pink,pioneer,pipe,pistol,pitch,pizza,place,planet,plastic,plate,play,please,pledge,pluck,plug,plunge,poem,poet," +
"point,polar,pole,police,pond,pony,pool,popular,portion,position,possible,post,potato,pottery,poverty,powder,power,practice," +
"praise,predict,prefer,prepare,present,pretty,prevent,price,pride,primary,print,priority,prison,private,prize,problem,process," +
"produce,profit,program,project,promote,proof,property,prosper,protect,proud,provide,public,pudding,pull,pulp,pulse,pumpkin," +
"punch,pupil,puppy,purchase,purity,purpose,purse,push,put,puzzle,pyramid,quality,quantum,quarter,question,quick,quit,quiz,quote," +
"rabbit,raccoon,race,rack,radar,radio,rail,rain,raise,rally,ramp,ranch,random,range,rapid,rare,rate,rather,raven,raw,razor," +
"ready,real,reason,rebel,rebuild,recall,receive,recipe,record,recycle,reduce,reflect,reform,refuse,region,regret,regular,reject," +
"relax,release,relief,rely,remain,remember,remind,remove,render,renew,rent,reopen,repair,repeat,replace,report,require,rescue," +
"resemble,resist,resource,response,result,retire,retreat,return,reunion,reveal,review,reward,rhythm,rib,ribbon,rice,rich,ride," +
"ridge,rifle,right,rigid,ring,riot,ripple,risk,ritual,rival,river,road,roast,robot,robust,rocket,romance,roof,rookie,room,rose," +
"rotate,rough,round,route,royal,rubber,rude,rug,rule,run,runway,rural,sad,saddle,sadness,safe,sail,salad,salmon,salon,salt," +
"salute,same,sample,sand,satisfy,satoshi,sauce,sausage,save,say,scale,scan,scare,scatter,scene,scheme,school,science,scissors," +
"scorpion,scout,scrap,screen,script,scrub,sea,search,season,seat,second,secret,section,security,seed,seek,segment,select,sell," +
"seminar,senior,sense,sentence,series,service,session,settle,setup,seven,shadow,shaft,shallow,share,shed,shell,sheriff,shield," +
"shift,shine,ship,shiver,shock,shoe,shoot,shop,short,shoulder,shove,shrimp,shrug,shuffle,shy,sibling,sick,side,siege,sight," +
"sign,silent,silk,silly,silver,similar,simple,since,sing,siren,sister,situate,six,size,skate,sketch,ski,skill,skin,skirt,skull," +
"slab,slam,sleep,slender,slice,slide,slight,slim,slogan,slot,slow,slush,small,smart,smile,smoke,smooth,snack,snake,snap,sniff," +
"snow,soap,soccer,social,sock,soda,soft,solar,soldier,solid,solution,solve,someone,song,soon,sorry,sort,soul,sound,soup,source," +
"south,space,spare,spatial,spawn,speak,special,speed,spell,spend,sphere,spice,spider,spike,spin,spirit,split,spoil,sponsor," +
"spoon,sport,spot,spray,spread,spring,spy,square,squeeze,squirrel,stable,stadium,staff,stage,stairs,stamp,stand,start,state," +
"stay,steak,steel,stem,step,stereo,stick,still,sting,stock,stomach,stone,stool,story,stove,strategy,street,strike,strong,struggle," +
"student,stuff,stumble,style,subject,submit,subway,success,such,sudden,suffer,sugar,suggest,suit,summer,sun,sunny,sunset,super," +
"supply,supreme,sure,surface,surge,surprise,surround,survey,suspect,sustain,swallow,swamp,swap,swarm,swear,sweet,swift,swim," +
"swing,switch,sword,symbol,symptom,syrup,system,table,tackle,tag,tail,talent,talk,tank,tape,target,task,taste,tattoo,taxi,teach," +
"team,tell,ten,tenant,tennis,tent,term,test,text,thank,that,theme,then,theory,there,they,thing,this,thought,three,thrive,throw," +
"thumb,thunder,ticket,tide,tiger,tilt,timber,time,tiny,tip,tired,tissue,title,toast,tobacco,today,toddler,toe,together,toilet," +
"token,tomato,tomorrow,tone,tongue,tonight,tool,tooth,top,topic,topple,torch,tornado,tortoise,toss,total,tourist,toward,tower," +
"town,toy,track,trade,traffic,tragic,train,transfer,trap,trash,travel,tray,treat,tree,trend,trial,tribe,trick,trigger,trim," +
"trip,trophy,trouble,truck,true,truly,trumpet,trust,truth,try,tube,tuition,tumble,tuna,tunnel,turkey,turn,turtle,twelve,twenty," +
"twice,twin,twist,two,type,typical,ugly,umbrella,unable,unaware,uncle,uncover,under,undo,unfair,unfold,unhappy,uniform,unique," +
"unit,universe,unknown,unlock,until,unusual,unveil,update,upgrade,uphold,upon,upper,upset,urban,urge,usage,use,used,useful," +
"useless,usual,utility,vacant,vacuum,vague,valid,valley,valve,van,vanish,vapor,various,vast,vault,vehicle,velvet,vendor,venture," +
"venue,verb,verify,version,very,vessel,veteran,viable,vibrant,vicious,victory,video,view,village,vintage,violin,virtual,virus," +
"visa,visit,visual,vital,vivid,vocal,voice,void,volcano,volume,vote,voyage,wage,wagon,wait,walk,wall,walnut,want,warfare,warm," +
"warrior,wash,wasp,waste,water,wave,way,wealth,weapon,wear,weasel,weather,web,wedding,weekend,weird,welcome,west,wet,whale," +
"what,wheat,wheel,when,where,whip,whisper,wide,width,wife,wild,will,win,window,wine,wing,wink,winner,winter,wire,wisdom,wise," +
"wish,witness,wolf,woman,wonder,wood,wool,word,work,world,worry,worth,wrap,wreck,wrestle,wrist,write,wrong,yard,year,yellow," +
"you,young,youth,zebra,zero,zone,zoo").split(',')
